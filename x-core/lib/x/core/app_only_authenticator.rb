# frozen_string_literal: true

require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "errors/unauthorized"
require_relative "origin"
require_relative "token_endpoint"

module X
  # Authenticates as an app with a bearer token, fetched with the API key and secret when first needed
  #
  # A bearer token the API rejects with 401 Unauthorized, as it does one that was invalidated, is dropped, and the
  # request is sent again with one fetched in its place.
  #
  # @api public
  class AppOnlyAuthenticator < Authenticator
    # The endpoint that exchanges an API key and secret for a bearer token
    TOKEN_URL = "https://api.x.com/oauth2/token"
    # The message raised when the token endpoint describes no reason for the failure
    DEFAULT_ERROR_MESSAGE = "Bearer token request failed"
    private_constant :DEFAULT_ERROR_MESSAGE

    # The API key
    # @api public
    # @return [String] the API key
    # @example Get the API key
    #   authenticator.api_key
    attr_reader :api_key

    # Initialize a new app-only authenticator
    #
    # @api public
    # @param api_key [String] the API key
    # @param api_key_secret [String] the API key secret
    # @param bearer_token [String, nil] a bearer token already fetched with these credentials
    # @return [AppOnlyAuthenticator] a new authenticator
    # @example Create an app-only authenticator
    #   X::AppOnlyAuthenticator.new(api_key: "key", api_key_secret: "secret")
    def initialize(api_key:, api_key_secret:, bearer_token: nil)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @bearer_token = bearer_token
      @connection = Core::Connection.new
      @mutex = Mutex.new
    end

    # Generate the authentication header, fetching the bearer token first if needed
    #
    # Internal to x-core: RequestBuilder signs its requests with it, and it takes the Net::HTTP request it signs,
    # so that it can change within 1.x, as that request may.
    #
    # @api private
    # @param _request [Net::HTTPRequest, nil] the request, which app-only authentication does not sign
    # @return [Hash{String => String}] the authorization header
    # @raise [AuthorizationError] if X refuses to issue the bearer token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Generate the header
    #   authenticator.header(request) # => {"Authorization" => "Bearer ..."}
    def header(_request)
      {AUTHENTICATION_HEADER => "Bearer #{bearer_token}"}
    end

    private

    # The bearer token, fetched once with the API key and secret
    #
    # It is a secret, so it is private, as the bearer token of a BearerTokenAuthenticator is. Internal to x-core:
    # a client that authenticates as the app fetches its token through it, and calls it with __send__.
    #
    # @api private
    # @return [String] the bearer token
    # @raise [AuthorizationError] if X refuses to issue the bearer token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Get the bearer token
    #   bearer_token
    def bearer_token
      @mutex.synchronize { @bearer_token ||= fetch_bearer_token }
    end

    # The connection the bearer token is fetched over
    # @api private
    # @return [Core::Connection] the connection
    attr_reader :connection

    # Fetch the bearer token over a connection
    #
    # Internal to x-core: a client fetches the token of the authenticator it builds over its own connection, with its
    # proxy, timeouts, and debug output, and calls it with __send__, since it is private.
    #
    # @api private
    # @param connection [Core::Connection] the connection to fetch the token over
    # @return [AppOnlyAuthenticator] the authenticator
    def token_requests_over(connection)
      @connection = connection
      self
    end

    # The API key secret, which buys the bearer token
    # @api private
    # @return [String] the API key secret
    # @example Buy a bearer token with the API key secret
    #   api_key_secret
    attr_reader :api_key_secret

    # Run a request, again with a bearer token fetched in place of one the API rejects
    #
    # Only a rejection by the origin the token is sent to drops it; see {Core::Origin}. A token fetched for the
    # request itself is not fetched again, since the endpoint that just issued it would issue it again. Internal to
    # x-core: Client runs each request through it, and calls it with __send__, since it is private.
    #
    # @api private
    # @param origin [URI::Generic] the base URL of the client, the origin the token is sent to
    # @yield runs the request
    # @return [Object] what the block returns
    # @raise [Unauthorized] if the API rejects the token fetched in place of the one it rejected
    def retrying_rejected_token(origin)
      token = @bearer_token
      begin
        yield
      rescue Unauthorized => e
        raise unless token && Core::Origin.answered?(e, origin)

        drop_bearer_token(token)
        yield
      end
    end

    # Drop a bearer token the API rejected, unless another request already replaced it
    # @api private
    # @param rejected [String] the bearer token the API rejected
    # @return [void]
    def drop_bearer_token(rejected)
      @mutex.synchronize { @bearer_token = nil if @bearer_token.eql?(rejected) }
    end

    # Exchange the API key and secret for a bearer token
    # @api private
    # @return [String] the bearer token
    # @raise [AuthorizationError] if the token endpoint rejects the request
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    def fetch_bearer_token
      Core::TokenEndpoint.fetch(token_request, connection:).access_token
    rescue SimpleOAuth::OAuth2::Error => e
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE)
    end

    # Build the client credentials request
    # @api private
    # @return [SimpleOAuth::OAuth2::Request] the token request
    def token_request
      SimpleOAuth::OAuth2::Client.new(client_id: api_key, client_secret: api_key_secret, token_endpoint: TOKEN_URL)
        .client_credentials_request
    end
  end
end
