require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "errors/unauthorized"
require_relative "token_endpoint"

module X
  # Handles OAuth 2.0 authentication, refreshing the access token when it expires
  #
  # X issues a new refresh token with each access token and accepts a refresh token once, so an authenticator
  # refreshes under a lock, and calls on_refresh with itself so that the new tokens can be stored.
  #
  # @api public
  class OAuth2Authenticator < Authenticator
    # Path for the OAuth 2.0 token endpoint
    TOKEN_PATH = "/2/oauth2/token".freeze
    # Host for token refresh requests
    TOKEN_HOST = "api.x.com".freeze
    # Buffer time in seconds to account for clock skew and network latency
    EXPIRATION_BUFFER = 30
    # The message raised when the token endpoint describes no reason for the failure
    DEFAULT_ERROR_MESSAGE = "Token refresh failed".freeze

    # The OAuth 2.0 client ID
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authenticator.client_id
    attr_reader :client_id
    # The OAuth 2.0 client secret
    # @api public
    # @return [String, nil] the client secret, or nil for a public client
    # @example Get the client secret
    #   authenticator.client_secret
    attr_reader :client_secret
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
    # @api public
    # @return [Connection] the connection instance
    # @example Get the connection
    #   authenticator.connection
    attr_reader :connection

    # A callable passed the authenticator after each refresh, to store its new tokens
    # @api public
    # @return [#call, nil] the callable, or nil for none
    # @example Get the callable
    #   authenticator.on_refresh
    attr_reader :on_refresh

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
    # @param on_refresh [#call, nil] a callable passed the authenticator after each refresh
    # @return [OAuth2Authenticator] a new authenticator instance
    # @example Create an authenticator
    #   authenticator = X::OAuth2Authenticator.new(
    #     client_id: "id",
    #     client_secret: "secret",
    #     access_token: "token",
    #     refresh_token: "refresh"
    #   )
    def initialize(client_id:, access_token:, refresh_token:, client_secret: nil, expires_at: nil,
      connection: Connection.new, on_refresh: nil)
      @client_id = client_id
      @client_secret = client_secret
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      @connection = connection
      @on_refresh = on_refresh
      @mutex = Mutex.new
    end

    # Generate the authentication header, refreshing an expired token first
    #
    # @api public
    # @param _request [Net::HTTPRequest, nil] the HTTP request (unused)
    # @return [Hash{String => String}] the authentication header
    # @raise [AuthorizationError] if the token has expired and X refuses to refresh it
    # @example Get the header
    #   authenticator.header(request)
    def header(_request)
      refreshed = @mutex.synchronize { refresh if token_expired? }
      report_refresh if refreshed
      {AUTHENTICATION_HEADER => "Bearer #{access_token}"}
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
    # @api public
    # @return [Hash{String => Object}] the token response
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @example Refresh the token
    #   authenticator.refresh_token!
    def refresh_token!
      @mutex.synchronize { refresh }.tap { report_refresh }
    end

    # Refresh an access token the API rejected, unless it was already replaced
    #
    # Requests that were sent with the same token, and rejected together, refresh it once between them.
    #
    # @api public
    # @param rejected_token [String] the access token the API rejected
    # @return [Boolean] true if the access token is no longer the one rejected
    # @raise [AuthorizationError] if X refuses to refresh the token
    # @example Refresh a token the API rejected, and retry
    #   retry if authenticator.refresh_rejected_token!(token)
    def refresh_rejected_token!(rejected_token)
      refreshed, replaced = @mutex.synchronize do
        [(refresh if access_token.eql?(rejected_token)), !access_token.eql?(rejected_token)]
      end
      report_refresh if refreshed
      replaced
    end

    # Run a request, again if the API rejects a token that a refresh replaces
    #
    # X rejects an expired access token with 401 Unauthorized, which an authenticator that does not know when
    # its token expires learns only from the rejection.
    #
    # @api private
    # @yield runs the request
    # @return [Object] what the block returns
    # @raise [Unauthorized] if the request is rejected again, or a refresh does not replace the access token
    def retrying_rejected_token
      token = access_token
      begin
        yield
      rescue Unauthorized
        raise unless refresh_rejected_token!(token)

        yield
      end
    end

    private

    # Refresh the access token, holding the lock
    # @api private
    # @return [Hash{String => Object}] the token response
    # @raise [AuthorizationError] if X refuses to refresh the token
    def refresh
      token = TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:)
      update_tokens(token)
      token.params
    rescue SimpleOAuth::OAuth2::Error => e
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE)
    end

    # Pass the authenticator to on_refresh, once the lock is released
    #
    # The callable can make a request of its own, such as looking up the user whose tokens it stores, which
    # asks this authenticator for a header and so takes the lock again.
    #
    # @api private
    # @return [void]
    def report_refresh
      on_refresh&.call(self)
    end

    # The client for the token endpoint
    # @api private
    # @return [SimpleOAuth::OAuth2::Client] the OAuth 2.0 client
    def oauth2_client
      SimpleOAuth::OAuth2::Client.new(client_id:, client_secret:, token_endpoint: token_endpoint)
    end

    # The URL of the token endpoint
    # @api private
    # @return [String] the token endpoint URL
    def token_endpoint
      "https://#{TOKEN_HOST}#{TOKEN_PATH}"
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
