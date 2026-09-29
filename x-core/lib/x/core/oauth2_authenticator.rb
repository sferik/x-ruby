# frozen_string_literal: true

require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "credential_validator"
require_relative "errors/unsupported_operation"
require_relative "oauth2_refresh"
require_relative "refresh_reporter"

module X
  # Handles OAuth 2.0 authentication, refreshing the access token when it expires
  #
  # X issues a new refresh token with each access token and accepts a refresh token once, so an authenticator
  # refreshes under a lock, and the authenticator of a client passes the tokens each refresh issued, as OAuth2Tokens,
  # to the on_token_refresh of that client and of each copy of it that shares the authenticator, so that they can be
  # stored.
  #
  # X issues no refresh token for an authorization without the offline.access scope, so an authenticator built
  # without one authenticates as the user until its access token expires, and refreshes nothing: a request sent
  # with an access token that expired is sent as it is, for the API to reject with Unauthorized, and one the API
  # rejects is not sent again.
  #
  # @api public
  class OAuth2Authenticator < Authenticator
    include Core::OAuth2Refresh

    # The endpoint that refreshes an access token
    TOKEN_URL = "https://api.x.com/2/oauth2/token"
    # Buffer time in seconds to account for clock skew and network latency
    EXPIRATION_BUFFER = 30
    private_constant :EXPIRATION_BUFFER
    # The message raised for a refresh of an authenticator that holds no refresh token
    NO_REFRESH_TOKEN = "The authenticator holds no refresh token, which X issues only for an authorization with the " \
      "offline.access scope, so its access token cannot be refreshed. Ask the user to authorize the app again, with " \
      "offline.access to refresh the token that authorization issues"
    private_constant :NO_REFRESH_TOKEN

    # The OAuth 2.0 client ID
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authenticator.client_id
    attr_reader :client_id
    # The expiration time of the access token
    # @api public
    # @return [Time, nil] the expiration time
    # @example Get the expiration time
    #   authenticator.expires_at
    attr_reader :expires_at

    # Initialize a new OAuth 2.0 authenticator
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID
    # @param client_secret [String, nil] the OAuth 2.0 client secret, or nil for a public client, which sends its
    #   client ID in the body of a refresh instead of authenticating with a secret
    # @param access_token [String] the OAuth 2.0 access token
    # @param refresh_token [String, nil] the OAuth 2.0 refresh token, or nil for an access token issued without the
    #   offline.access scope, which the authenticator cannot refresh
    # @param expires_at [Time, nil] the expiration time of the access token
    # @return [OAuth2Authenticator] a new authenticator instance
    # @raise [ArgumentError] if the client ID or access token is nil or empty, the refresh token or client secret is
    #   empty, or the expiration time is neither a Time nor nil
    # @example Create an authenticator
    #   authenticator = X::OAuth2Authenticator.new(
    #     client_id: "id",
    #     client_secret: "secret",
    #     access_token: "token",
    #     refresh_token: "refresh"
    #   )
    def initialize(client_id:, access_token:, refresh_token: nil, client_secret: nil, expires_at: nil)
      Core::CredentialValidator.validate_required!({client_id:, access_token:}, {refresh_token:, client_secret:, expires_at:})
      @client_id = client_id
      @client_secret = client_secret
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      @connection = Core::Connection.new
      @mutex = Mutex.new
      @reporter = Core::RefreshReporter.new
      @clients = ObjectSpace::WeakMap.new
    end

    # Generate the authentication header, refreshing an expired token first
    #
    # An authenticator that holds no refresh token sends an access token that expired as it is, for the API to reject.
    #
    # @api public
    # @param _request [#method, #uri, #body, #[], nil] the request, which a bearer token does not sign
    # @return [Hash{String => String}] the authentication header
    # @raise [AuthorizationError] if the token has expired and X refuses to refresh it
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Get the header
    #   authenticator.header(request)
    def header(_request)
      refresh_expired_token(connection)
      {AUTHENTICATION_HEADER => "Bearer #{access_token}"}
    end

    # Summarize the authenticator for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name, client ID, and expiration time
    # @example Inspect an authenticator
    #   authenticator.inspect # => #<X::OAuth2Authenticator client_id="id" expires_at=nil>
    def inspect = "#<#{self.class} client_id=#{client_id.inspect} expires_at=#{expires_at.inspect}>"

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
    # The authenticator holds the new tokens once it returns, and the authenticator of a client has passed them to the
    # on_token_refresh of the clients that share it. The tokens it returns are those of this refresh, frozen, the
    # same object on_token_refresh is passed, so they are a set that belongs together, whatever refreshes follow on
    # other threads.
    #
    # @api public
    # @return [OAuth2Tokens] the tokens the refresh issued
    # @raise [UnsupportedOperation] if the authenticator holds no refresh token, before any request
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Refresh the tokens and store them
    #   store.save(**authenticator.refresh!.to_h)
    def refresh!
      raise UnsupportedOperation, NO_REFRESH_TOKEN unless refresh_token

      tokens = @mutex.synchronize { refresh(connection) }
      report_refresh(tokens)
      tokens
    end

    private

    # The OAuth 2.0 access token, as last refreshed
    #
    # It is a secret, so it is private, as the access token of a client is, since a client hands out its
    # authenticator. The tokens of a refresh are passed to on_token_refresh, and returned by {#refresh!}. Internal to
    # x-core: a client reads it with __send__.
    #
    # @api private
    # @return [String] the access token
    attr_reader :access_token

    # The OAuth 2.0 refresh token, as last refreshed
    #
    # It is private for the reason {#access_token} is.
    #
    # @api private
    # @return [String, nil] the refresh token, or nil for an authenticator that cannot refresh
    attr_reader :refresh_token

    # The OAuth 2.0 client secret, which authenticates a refresh
    # @api private
    # @return [String, nil] the client secret, or nil for a public client
    # @example Refresh with the client secret
    #   client_secret
    attr_reader :client_secret

    # The connection for making token requests
    #
    # refresh! sends its request over it, as does a request signed with the authenticator alone. A client refreshes
    # over its own connection instead, so that the copies of a client that share its authenticator, but were given
    # another proxy, other timeouts, or other debug output, refresh with those.
    #
    # @api private
    # @return [Core::Connection] the connection
    attr_reader :connection

    # The clients that authenticate with the authenticator, held weakly
    #
    # Each refresh reaches the on_token_refresh of each of them. Internal to x-core: a client joins the clients of the
    # authenticator it builds, shares with the client it was copied from, or is given, and reads them with __send__,
    # since they are private.
    #
    # @api private
    # @return [ObjectSpace::WeakMap] the clients, each held as a key
    attr_reader :clients

    # Send the token requests over the connection of the first client that takes it
    #
    # The authenticator is shared by the copies of the client that takes it, and may be given to other clients
    # besides, so a client that takes it after the first leaves it sending them over the connection of the first,
    # as a copy of a client leaves the authenticator of that client. Internal to x-core: a client sends the token
    # requests of the authenticator it builds, or is given, over its own connection, with its proxy, timeouts, and
    # debug output, and calls it with __send__, since it is private.
    #
    # @api private
    # @param connection [Core::Connection] the connection to send the token requests over
    # @return [OAuth2Authenticator] the authenticator
    def token_requests_over(connection)
      @mutex.synchronize do
        @connection = connection unless @taken
        @taken = true
      end
      self
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

    # Pass each refresh to the callables another reads
    #
    # Internal to x-core: Client passes the refreshes of the authenticator it builds to the on_token_refresh of each
    # client that shares it, and calls it with __send__, since it is private.
    #
    # @api private
    # @param hooks [#call] a callable that returns the callables to pass each refresh, read at each refresh
    # @return [#call] the callable
    def report_refreshes_to(hooks) = @reporter.to(hooks)

    # The client for the token endpoint
    # @api private
    # @return [SimpleOAuth::OAuth2::Client] the OAuth 2.0 client
    def oauth2_client = SimpleOAuth::OAuth2::Client.new(client_id:, client_secret:, token_endpoint: TOKEN_URL)
  end
end
