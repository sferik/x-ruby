require "securerandom"
require "simple_oauth"
require "uri"
require_relative "client"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "oauth2_authenticator"
require_relative "token_endpoint"

module X
  # Authorizes an app to act for a user with the OAuth 2.0 authorization code flow and PKCE
  #
  # The flow takes two requests to the app: one that sends the user to X to authorize it, and one that X redirects
  # the user back to. The state and code verifier of the first must reach the second, so store them, as in the
  # session, and build the authorization again with them when X redirects back.
  #
  # @api public
  class OAuth2Authorization
    # The page that asks a user to authorize an app
    AUTHORIZATION_URL = "https://x.com/i/oauth2/authorize".freeze
    # The endpoint that exchanges an authorization code for tokens
    TOKEN_URL = "https://#{OAuth2Authenticator::TOKEN_HOST}#{OAuth2Authenticator::TOKEN_PATH}".freeze
    # The scopes that read posts and users, and keep a refresh token to act for the user after the access token expires
    DEFAULT_SCOPES = %w[tweet.read users.read offline.access].freeze
    # The number of random bytes in a generated state
    STATE_BYTES = 32
    # The message raised when X describes no reason for a failed authorization
    DEFAULT_ERROR_MESSAGE = "Authorization failed".freeze
    # The message raised for a redirect back from X that is not a valid URL
    INVALID_CALLBACK_MESSAGE = "The redirect back from X is not a valid URL".freeze

    # The OAuth 2.0 client ID of the app
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authorization.client_id
    attr_reader :client_id

    # The OAuth 2.0 client secret of a confidential app
    # @api public
    # @return [String, nil] the client secret, or nil for a public client
    # @example Get the client secret
    #   authorization.client_secret
    attr_reader :client_secret

    # The URL X redirects the user back to, as registered for the app
    # @api public
    # @return [String] the redirect URI
    # @example Get the redirect URI
    #   authorization.redirect_uri
    attr_reader :redirect_uri

    # The scopes the app asks the user for
    # @api public
    # @return [Array<String>] the scopes
    # @example Get the scopes
    #   authorization.scopes # => ["tweet.read", "users.read", "offline.access"]
    attr_reader :scopes

    # The value that ties the redirect back from X to this authorization
    # @api public
    # @return [String] the state
    # @example Store the state in the session
    #   session[:state] = authorization.state
    attr_reader :state

    # The PKCE code verifier, to store until X redirects back
    # @api public
    # @return [String] the code verifier
    # @example Store the code verifier in the session
    #   session[:code_verifier] = authorization.code_verifier
    attr_reader :code_verifier

    # The connection that exchanges the authorization code for tokens
    # @api public
    # @return [Connection] the connection
    # @example Get the connection
    #   authorization.connection
    attr_reader :connection

    # Initialize an authorization
    #
    # A new state and code verifier are generated unless they are given.
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID of the app
    # @param redirect_uri [String] the URL X redirects the user back to, as registered for the app
    # @param client_secret [String, nil] the client secret of a confidential app, or nil for a public client
    # @param scopes [Array<String>] the scopes to ask the user for; offline.access keeps a refresh token
    # @param state [String] the state, as stored when the user was sent to X
    # @param code_verifier [String] the PKCE code verifier, as stored when the user was sent to X
    # @param connection [Connection] the connection that exchanges the authorization code for tokens
    # @return [OAuth2Authorization] a new authorization
    # @raise [ArgumentError] if the state is nil or empty, which would accept the redirect of any authorization
    # @raise [ArgumentError] if the code verifier is not 43 to 128 unreserved characters
    # @example Start an authorization
    #   authorization = X::OAuth2Authorization.new(client_id: "id", redirect_uri: "https://example.com/callback")
    def initialize(client_id:, redirect_uri:, client_secret: nil, scopes: DEFAULT_SCOPES, state: SecureRandom.urlsafe_base64(STATE_BYTES),
      code_verifier: SimpleOAuth::OAuth2::PKCE.generate.verifier, connection: Connection.new)
      raise ArgumentError, "state must not be nil or empty; pass the state stored when the user was sent to X" if state.to_s.empty?

      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @scopes = scopes
      @state = state
      @pkce = SimpleOAuth::OAuth2::PKCE.new(verifier: code_verifier)
      @code_verifier = code_verifier
      @connection = connection
    end

    # Summarize the authorization for the console without revealing its secrets
    #
    # @api public
    # @return [String] the class name, client ID, redirect URI, and scopes
    # @example Inspect an authorization
    #   authorization.inspect # => #<X::OAuth2Authorization client_id="id" redirect_uri="https://example.com/callback" ...>
    def inspect
      "#<#{self.class} client_id=#{client_id.inspect} redirect_uri=#{redirect_uri.inspect} scopes=#{scopes}>"
    end

    # The page on X that asks the user to authorize the app, to redirect the user to
    #
    # @api public
    # @return [String] the authorization URL, with the state and PKCE code challenge
    # @example Send the user to X
    #   redirect_to authorization.url
    def url
      oauth2_client.authorization_url(redirect_uri:, pkce: @pkce, state:, scope: scopes)
    end

    # Exchange the code of the redirect back from X for the credentials of a client
    #
    # An authorization code works once, so call this, or {#client}, once for each redirect.
    #
    # @api public
    # @param callback [String, Hash] the redirect back from X: its URL, its query string, or its query parameters
    # @return [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them: the client ID,
    #   client secret, access token, refresh token, and expiration time, or the access token alone as a bearer token
    #   without offline.access
    # @raise [AuthorizationError] if the user denied the app, the state does not match, X refuses the code, or the
    #   redirect is not a valid URL
    # @example Store the credentials of the user
    #   store.save(authorization.credentials(request.url))
    def credentials(callback)
      code = SimpleOAuth::OAuth2::AuthorizationResponse.parse(query_of(callback), state:).code
      token = TokenEndpoint.fetch(oauth2_client.authorization_code_request(code:, redirect_uri:, code_verifier:), connection:)
      credentials_from(token)
    rescue SimpleOAuth::OAuth2::Error => e
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE)
    end

    # Exchange the code of the redirect back from X for a client
    #
    # @api public
    # @param callback [String, Hash] the redirect back from X: its URL, its query string, or its query parameters
    # @param options [Hash] other options of Client#initialize, such as on_token_refresh
    # @return [Client] a client with the user's credentials
    # @raise [AuthorizationError] if the user denied the app, the state does not match, X refuses the code, or the
    #   redirect is not a valid URL
    # @example Act for the user who authorized the app
    #   client = authorization.client(request.url, on_token_refresh: ->(auth) { store.save(auth.refresh_token) })
    def client(callback, **options)
      Client.new(**credentials(callback), **options)
    end

    private

    # The client for the authorization page and token endpoint
    # @api private
    # @return [SimpleOAuth::OAuth2::Client] the OAuth 2.0 client
    def oauth2_client
      SimpleOAuth::OAuth2::Client.new(client_id:, client_secret:, authorization_endpoint: AUTHORIZATION_URL,
        token_endpoint: TOKEN_URL)
    end

    # The query of a redirect back from X
    # @api private
    # @param callback [String, Hash] the redirect: its URL, its query string, or its query parameters
    # @return [String, Hash] the query string, or the query parameters
    # @raise [AuthorizationError] if the redirect is not a valid URL
    def query_of(callback)
      String.try_convert(callback)&.then { |url| URI(url).query } || callback
    rescue URI::InvalidURIError
      raise AuthorizationError.new(INVALID_CALLBACK_MESSAGE)
    end

    # The credentials of a client from the token X returned
    # @api private
    # @param token [SimpleOAuth::OAuth2::Token] the token
    # @return [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
    def credentials_from(token)
      access_token = token.access_token
      refresh_token = token.refresh_token
      return {bearer_token: access_token} if refresh_token.nil?

      {client_id:, client_secret:, access_token:, refresh_token:, expires_at: token.expires_at}
    end
  end
end
