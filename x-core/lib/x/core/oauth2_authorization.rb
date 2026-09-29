# frozen_string_literal: true

require "securerandom"
require "simple_oauth"
require "uri"
require_relative "client"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "errors/token_report_failed"
require_relative "oauth2_authenticator"
require_relative "oauth2_tokens"
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
    AUTHORIZATION_URL = "https://x.com/i/oauth2/authorize"
    # The endpoint that exchanges an authorization code for tokens
    TOKEN_URL = OAuth2Authenticator::TOKEN_URL
    # The scopes that read posts and users, and keep a refresh token to act for the user after the access token expires
    DEFAULT_SCOPES = %w[tweet.read users.read offline.access].freeze
    # The number of random bytes in a generated state
    STATE_BYTES = 32
    private_constant :STATE_BYTES
    # The message raised when X describes no reason for a failed authorization
    DEFAULT_ERROR_MESSAGE = "Authorization failed"
    private_constant :DEFAULT_ERROR_MESSAGE
    # The message raised for a redirect back from X that is not a valid URL
    INVALID_CALLBACK_MESSAGE = "The redirect back from X is not a valid URL"
    private_constant :INVALID_CALLBACK_MESSAGE
    # The options of Client#initialize that the exchange of the code gives the client of #client
    CREDENTIALS = %i[api_key api_key_secret access_token access_token_secret bearer_token client_id client_secret
      refresh_token expires_at authenticator].freeze
    private_constant :CREDENTIALS
    # The message raised for credentials given to #client, which the exchange of the code gives the client
    CREDENTIALS_GIVEN_MESSAGE = "The client of an authorization authenticates with the tokens X exchanges the code " \
      "for, so it cannot be given %s"
    private_constant :CREDENTIALS_GIVEN_MESSAGE

    # The OAuth 2.0 client ID of the app
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authorization.client_id
    attr_reader :client_id

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

    # Initialize an authorization
    #
    # A new state and code verifier are generated unless they are given. The authorization code is exchanged for
    # tokens with the proxy, timeouts, keep-alive timeout, and debug output given, which a client built with {#client}
    # is given too.
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID of the app
    # @param redirect_uri [String] the URL X redirects the user back to, as registered for the app
    # @param client_secret [String, nil] the client secret of a confidential app, or nil for a public client
    # @param scopes [Array<String>] the scopes to ask the user for; offline.access keeps a refresh token
    # @param state [String] the state, as stored when the user was sent to X
    # @param code_verifier [String] the PKCE code verifier, as stored when the user was sent to X
    # @param proxy_url [String, URI::Generic, nil] the proxy URL for the token request
    # @param open_timeout [Integer, Float, nil] the timeout for opening connections in seconds, or nil for none
    # @param read_timeout [Integer, Float, nil] the timeout for reading responses in seconds, or nil for none
    # @param write_timeout [Integer, Float, nil] the timeout for writing requests in seconds, or nil for none
    # @param keep_alive_timeout [Integer, Float] the time to keep a connection open for the next request to the same
    #   host, in seconds, which a proxy that closes idle connections sooner than X does may need lowered
    # @param debug_output [IO, #<<, nil] the IO object for debug output, or anything else that takes a String with <<,
    #   such as a StringIO. It is written every request and response whole, in the clear: the Authorization header,
    #   the client secret a token request sends, and the tokens a token response holds. Send it to a file you
    #   control while debugging, never to a log that is shipped elsewhere, and leave it nil in production.
    # @return [OAuth2Authorization] a new authorization
    # @raise [ArgumentError] if the state is nil or empty, which would accept the redirect of any authorization
    # @raise [ArgumentError] if the code verifier is not 43 to 128 unreserved characters
    # @raise [ArgumentError] if a timeout is neither a finite number of seconds of at least 0 nor nil, or the
    #   keep-alive timeout is not a finite number of seconds of at least 0
    # @example Start an authorization
    #   authorization = X::OAuth2Authorization.new(client_id: "id", redirect_uri: "https://example.com/callback")
    def initialize(client_id:, redirect_uri:, client_secret: nil, scopes: DEFAULT_SCOPES, state: SecureRandom.urlsafe_base64(STATE_BYTES),
      code_verifier: SimpleOAuth::OAuth2::PKCE.generate.verifier, proxy_url: nil, open_timeout: Client::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Client::DEFAULT_READ_TIMEOUT, write_timeout: Client::DEFAULT_WRITE_TIMEOUT,
      keep_alive_timeout: Client::DEFAULT_KEEP_ALIVE_TIMEOUT, debug_output: nil)
      raise ArgumentError, "state must not be nil or empty; pass the state stored when the user was sent to X" if state.to_s.empty?

      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @scopes = scopes
      @state = state
      @pkce = SimpleOAuth::OAuth2::PKCE.new(verifier: code_verifier)
      @code_verifier = code_verifier
      @settings = {proxy_url:, open_timeout:, read_timeout:, write_timeout:, keep_alive_timeout:, debug_output:}
      @connection = Core::Connection.new(**@settings)
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
    #   the client secret of a confidential client, the access token, the refresh token, and the expiration time; an
    #   authorization without offline.access issues no refresh token, so its credentials hold none, and a client built
    #   of them acts for the user until the access token expires, and cannot authenticate as the app
    # @raise [AuthorizationError] if the user denied the app, the state does not match, X refuses the code, or the
    #   redirect is not a valid URL
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Store the credentials of the user
    #   store.save(authorization.credentials(request.url))
    def credentials(callback) = credentials_from(exchange(callback))

    # Exchange the code of the redirect back from X for a client
    #
    # The options are checked before the code is exchanged, since X accepts it once, so an option the client refuses,
    # such as a misspelled keyword, raises before the code is spent rather than after, with the tokens it was
    # exchanged for lost.
    #
    # The on_token_refresh of the client is passed the OAuth2Tokens of the exchange before the client is returned, as
    # it is passed those of each refresh after, so that a callable that stores them stores every refresh token X
    # issues, the first among them; a refresh token held by the client alone would be lost with it, and the user would
    # have to authorize the app again. It is passed nothing without offline.access, which issues no refresh token. A
    # callable that raises, as one whose storage is briefly down may, raises TokenReportFailed, which holds the client
    # and the tokens, so neither is lost with the code.
    #
    # @api public
    # @param callback [String, Hash] the redirect back from X: its URL, its query string, or its query parameters
    # @param options [Hash] other options of Client#initialize, such as on_token_refresh, which it is built with
    #   beside the proxy, timeouts, keep-alive timeout, and debug output of the authorization, and in place of them
    # @return [Client] a client with the user's credentials
    # @raise [ArgumentError] if an option is one Client#initialize refuses, or a credential or an authenticator,
    #   which the client is given by the exchange of the code
    # @raise [AuthorizationError] if the user denied the app, the state does not match, X refuses the code, or the
    #   redirect is not a valid URL
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @raise [TokenReportFailed] if on_token_refresh raises for the tokens of the exchange, with the client and tokens
    # @example Act for the user who authorized the app, storing the refresh token of the exchange and of each refresh
    #   client = authorization.client(request.url, on_token_refresh: ->(tokens) { store.save(tokens.refresh_token) })
    def client(callback, **options) # steep:ignore DifferentMethodParameterKind
      given = options.keys & CREDENTIALS
      raise ArgumentError, format(CREDENTIALS_GIVEN_MESSAGE, given.join(", ")) unless given.empty?

      Client.new(**options) # refuses an option before the code, which X accepts once, is spent
      token = exchange(callback)
      Client.new(**credentials_from(token), **@settings, **options).tap { |client| report_exchange(client, token) }
    end

    private

    # The OAuth 2.0 client secret of a confidential app
    #
    # It is private, as the secrets of a client and its authenticators are, and inspect leaves it out. The credentials
    # of an authorization hold it, since a client is built from them.
    #
    # @api private
    # @return [String, nil] the client secret, or nil for a public client
    attr_reader :client_secret

    # The connection that exchanges the authorization code for tokens
    # @api private
    # @return [Core::Connection] the connection
    attr_reader :connection

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

    # Exchange the code of the redirect back from X for a token
    # @api private
    # @param callback [String, Hash] the redirect back from X: its URL, its query string, or its query parameters
    # @return [SimpleOAuth::OAuth2::Token] the token
    # @raise [AuthorizationError] if the user denied the app, the state does not match, X refuses the code, or the
    #   redirect is not a valid URL
    def exchange(callback)
      code = SimpleOAuth::OAuth2::AuthorizationResponse.parse(query_of(callback), state:).code
      Core::TokenEndpoint.fetch(oauth2_client.authorization_code_request(code:, redirect_uri:, code_verifier:), connection:)
    rescue SimpleOAuth::OAuth2::Error => e
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE), cause: nil
    end

    # Pass the tokens of the exchange to the on_token_refresh of the client
    # @api private
    # @param client [Client] the client
    # @param token [SimpleOAuth::OAuth2::Token] the token of the exchange
    # @return [void]
    # @raise [TokenReportFailed] if on_token_refresh raises, with the client and tokens
    def report_exchange(client, token)
      refresh_token = token.refresh_token
      hook = client.on_token_refresh
      return unless refresh_token && hook

      tokens = OAuth2Tokens.new(access_token: token.access_token, refresh_token:, expires_at: token.expires_at)
      begin
        hook.call(tokens)
      rescue
        raise TokenReportFailed.new(client:, tokens:)
      end
    end

    # The credentials of a client from the token X returned
    #
    # They are OAuth 2.0 credentials whether or not X issued a refresh token, since the access token acts for the
    # user either way: one given as a bearer token would be taken for the app's, and sent to the endpoints that take
    # app-only authentication, which refuse it. A public client has no client secret, and a token issued without
    # offline.access no refresh token, so the credentials leave out either one that is missing.
    #
    # @api private
    # @param token [SimpleOAuth::OAuth2::Token] the token
    # @return [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
    def credentials_from(token)
      {client_id:, client_secret:, access_token: token.access_token, refresh_token: token.refresh_token}.compact
        .merge(expires_at: token.expires_at)
    end
  end
end
