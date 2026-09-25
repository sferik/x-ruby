# frozen_string_literal: true

require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "errors/unauthorized"
require_relative "origin"
require_relative "token_endpoint"

module X
  # Handles OAuth 2.0 authentication, refreshing the access token when it expires
  #
  # X issues a new refresh token with each access token and accepts a refresh token once, so an authenticator
  # refreshes under a lock, and calls on_token_refresh with itself so that the new tokens can be stored.
  #
  # @api public
  class OAuth2Authenticator < Authenticator
    # The endpoint that refreshes an access token
    TOKEN_URL = "https://api.x.com/2/oauth2/token"
    # Buffer time in seconds to account for clock skew and network latency
    EXPIRATION_BUFFER = 30
    private_constant :EXPIRATION_BUFFER
    # The message raised when the token endpoint describes no reason for the failure
    DEFAULT_ERROR_MESSAGE = "Token refresh failed"
    private_constant :DEFAULT_ERROR_MESSAGE

    # The OAuth 2.0 client ID
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authenticator.client_id
    attr_reader :client_id
    # The OAuth 2.0 access token
    # @api public
    # @return [String] the access token
    # @example Get the access token
    #   authenticator.access_token
    attr_reader :access_token
    # The OAuth 2.0 refresh token
    # @api public
    # @return [String] the refresh token
    # @example Get the refresh token
    #   authenticator.refresh_token
    attr_reader :refresh_token
    # The expiration time of the access token
    # @api public
    # @return [Time, nil] the expiration time
    # @example Get the expiration time
    #   authenticator.expires_at
    attr_reader :expires_at

    # The connection for making token requests
    #
    # refresh! sends its request over it, as does a request signed with the authenticator alone. A client refreshes
    # over its own connection instead, so that the copies of a client that share its authenticator, but were given
    # another proxy, other timeouts, or other debug output, refresh with those.
    #
    # @api public
    # @return [Connection] the connection instance
    # @example Get the connection
    #   authenticator.connection
    attr_reader :connection

    # A callable passed the authenticator after each refresh, to store its new tokens
    # @api public
    # @return [#call, nil] the callable, or nil for none
    # @example Get the callable
    #   authenticator.on_token_refresh
    attr_reader :on_token_refresh

    # Initialize a new OAuth 2.0 authenticator
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID
    # @param client_secret [String, nil] the OAuth 2.0 client secret, or nil for a public client, which sends its
    #   client ID in the body of a refresh instead of authenticating with a secret
    # @param access_token [String] the OAuth 2.0 access token
    # @param refresh_token [String] the OAuth 2.0 refresh token
    # @param expires_at [Time, nil] the expiration time of the access token
    # @param connection [Connection] the connection for making token requests
    # @param on_token_refresh [#call, nil] a callable passed the authenticator after each refresh
    # @return [OAuth2Authenticator] a new authenticator instance
    # @example Create an authenticator
    #   authenticator = X::OAuth2Authenticator.new(
    #     client_id: "id",
    #     client_secret: "secret",
    #     access_token: "token",
    #     refresh_token: "refresh"
    #   )
    def initialize(client_id:, access_token:, refresh_token:, client_secret: nil, expires_at: nil,
      connection: Connection.new, on_token_refresh: nil)
      @client_id = client_id
      @client_secret = client_secret
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      @connection = connection
      @on_token_refresh = on_token_refresh
      @mutex = Mutex.new
    end

    # Generate the authentication header, refreshing an expired token first
    #
    # Internal to x-core: RequestBuilder signs its requests with it, and it takes the Net::HTTP request it signs,
    # so that it can change within 1.x, as that request may.
    #
    # @api private
    # @param _request [Net::HTTPRequest, nil] the HTTP request (unused)
    # @return [Hash{String => String}] the authentication header
    # @raise [AuthorizationError] if the token has expired and X refuses to refresh it
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Get the header
    #   authenticator.header(request)
    def header(_request)
      refresh_expired_token(connection)
      {AUTHENTICATION_HEADER => "Bearer #{access_token}"}
    end

    # Check whether another authenticator holds the same OAuth 2.0 credentials
    #
    # Clients built from one set of credentials share an authenticator, so that a refresh by either reaches the
    # other, and this is what tells one set from another without handing the secret to the client that asks.
    #
    # @api public
    # @param other [Object] the other authenticator
    # @return [Boolean] true if the other authenticator holds the same credentials
    # @example Tell whether two clients refresh the same token
    #   client.authenticator.same_credentials?(other.authenticator)
    def same_credentials?(other)
      other.is_a?(OAuth2Authenticator) && credentials.eql?(other.__send__(:credentials))
    end

    # Summarize the authenticator for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name, client ID, and expiration time
    # @example Inspect an authenticator
    #   authenticator.inspect # => #<X::OAuth2Authenticator client_id="id" expires_at=nil>
    def inspect
      "#<#{self.class} client_id=#{client_id.inspect} expires_at=#{expires_at.inspect}>"
    end

    # Check if the access token has expired or will expire soon
    #
    # @api public
    # @return [Boolean] true if the token has expired or will expire within the buffer period
    # @example Check expiration
    #   authenticator.token_expired?
    def token_expired?
      return false if expires_at.nil?

      Time.now >= expires_at - EXPIRATION_BUFFER
    end

    # Refresh the access token using the refresh token
    #
    # The authenticator holds the new tokens once it returns, and has passed itself to on_token_refresh.
    #
    # @api public
    # @return [OAuth2Authenticator] the authenticator, which holds the new tokens
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Refresh the tokens and store them
    #   store(authenticator.refresh!.refresh_token)
    def refresh!
      @mutex.synchronize { refresh(connection) }
      report_refresh
      self
    end

    private

    # The OAuth 2.0 client secret, which authenticates a refresh
    # @api private
    # @return [String, nil] the client secret, or nil for a public client
    # @example Refresh with the client secret
    #   client_secret
    attr_reader :client_secret

    # The credentials that tell one authenticator from another
    # @api private
    # @return [Array<String, nil>] the client ID and secret, and the access and refresh tokens
    # @example Compare two authenticators
    #   credentials.eql?(other.credentials)
    def credentials = [client_id, client_secret, access_token, refresh_token]

    # Refresh the access token if it has expired, over a connection
    # @api private
    # @param connection [Connection] the connection to send the refresh over
    # @return [void]
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    def refresh_expired_token(connection)
      refreshed = @mutex.synchronize { refresh(connection) if token_expired? }
      report_refresh if refreshed
    end

    # Refresh an access token the API rejected, unless it was already replaced
    #
    # Requests that were sent with the same token, and rejected together, refresh it once between them.
    #
    # @api private
    # @param rejected_token [String] the access token the API rejected
    # @param connection [Connection] the connection to send the refresh over
    # @return [Boolean] true if the access token is no longer the one rejected
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    def refresh_rejected_token!(rejected_token, connection)
      refreshed, replaced = @mutex.synchronize do
        [(refresh(connection) if access_token.eql?(rejected_token)), !access_token.eql?(rejected_token)]
      end
      report_refresh if refreshed
      replaced
    end

    # Run a request, again if the API rejects a token that a refresh replaces
    #
    # X rejects an expired access token with 401 Unauthorized, which an authenticator that does not know when
    # its token expires learns only from the rejection. A 401 from another origin than the one the token is sent to
    # answers a request that carried no token, whether it named that origin or was redirected there, so it refreshes
    # nothing: X accepts a refresh token once, and a refresh would replace the tokens for a rejection of no token.
    #
    # A token that has expired is refreshed before the request, and one the API rejects after it, over the
    # connection given, which is the one of the client that sends the request: the copies of a client share its
    # authenticator, and a copy given another proxy, other timeouts, or other debug output refreshes the tokens it
    # shares with them, as it sends its requests with them.
    #
    # Internal to x-core: Client runs each request it sends with an OAuth 2.0 authenticator through it, and calls it
    # with __send__, since it is private.
    #
    # @api private
    # @param origin [URI::Generic] a URI of the origin the token is sent to, such as the base URL of a client
    # @param connection [Connection] the connection to send a refresh over
    # @yield runs the request
    # @return [Object] what the block returns
    # @raise [Unauthorized] if the request is rejected again, or by another origin, or a refresh does not replace
    #   the access token
    def retrying_rejected_token(origin, connection)
      refresh_expired_token(connection)
      token = access_token
      begin
        yield
      rescue Unauthorized => e
        raise unless carried_token?(e, origin) && refresh_rejected_token!(token, connection)

        yield
      end
    end

    # Check whether a rejection came from the origin the token is sent to
    #
    # A request answered by that origin carried the token, and one answered by another carried none.
    #
    # @api private
    # @param error [Unauthorized] the rejection
    # @param origin [URI::Generic] a URI of the origin the token is sent to
    # @return [Boolean] true if the response that rejected the request came from that origin
    def carried_token?(error, origin)
      uri = error.http_response.uri
      !uri.nil? && Core::Origin.same?(origin, uri)
    end

    # Check whether the authenticator holds the credentials among some options
    #
    # The options are those of a client, and the credentials among them its OAuth 2.0 ones.
    #
    # Internal to x-core: a copy of a client shares the authenticator unless it was given a credential this does not
    # hold, and calls it with __send__, since it is private.
    #
    # @api private
    # @param options [Hash{Symbol => Object}] the options of a client, of which the others are ignored
    # @return [Boolean] true if each client ID, client secret, access token, or refresh token among them is the one
    #   this holds
    def holds?(options)
      options.slice(:client_id, :client_secret, :access_token, :refresh_token) <= {client_id:, client_secret:, access_token:, refresh_token:}
    end

    # Set the expiration time of the access token, holding the lock
    #
    # Internal to x-core: Client sets the expiration time it is given on the authenticator that it and its copies
    # share, rather than build an authenticator of its own with the same refresh token, and calls it with __send__,
    # since it is private: a caller that set it would change the expiration every copy of the client reads.
    #
    # @api private
    # @param expires_at [Time, nil] the expiration time, or nil if it is not known
    # @return [void]
    def update_expires_at(expires_at)
      @mutex.synchronize { @expires_at = expires_at }
    end

    # Refresh the access token, holding the lock
    # @api private
    # @param connection [Connection] the connection to send the refresh over
    # @return [true] true, once the authenticator holds the new tokens
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    def refresh(connection)
      update_tokens(Core::TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:))
      true
    rescue SimpleOAuth::OAuth2::Error => e
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE)
    end

    # Pass the authenticator to on_token_refresh, once the lock is released
    #
    # The callable can make a request of its own, such as looking up the user whose tokens it stores, which
    # asks this authenticator for a header and so takes the lock again.
    #
    # @api private
    # @return [void]
    def report_refresh
      on_token_refresh&.call(self)
    end

    # The client for the token endpoint
    # @api private
    # @return [SimpleOAuth::OAuth2::Client] the OAuth 2.0 client
    def oauth2_client
      SimpleOAuth::OAuth2::Client.new(client_id:, client_secret:, token_endpoint: TOKEN_URL)
    end

    # Update tokens from the response
    # @api private
    # @param token [SimpleOAuth::OAuth2::Token] the token the endpoint returned
    # @return [void]
    def update_tokens(token)
      @access_token = token.access_token
      @refresh_token = token.refresh_token if token.refresh_token
      @expires_at = token.expires_at
    end
  end
end
