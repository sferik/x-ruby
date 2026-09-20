# frozen_string_literal: true

require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/authorization_error"
require_relative "token_endpoint"

module X
  # Authenticates as an app with a bearer token, fetched with the API key and secret when first needed
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
    # The API key secret
    # @api public
    # @return [String] the API key secret
    # @example Get the API key secret
    #   authenticator.api_key_secret
    attr_reader :api_key_secret
    # The connection used to fetch the bearer token
    # @api public
    # @return [Connection] the connection
    # @example Get the connection
    #   authenticator.connection
    attr_reader :connection

    # Initialize a new app-only authenticator
    #
    # @api public
    # @param api_key [String] the API key
    # @param api_key_secret [String] the API key secret
    # @param bearer_token [String, nil] a bearer token already fetched with these credentials
    # @param connection [Connection] the connection used to fetch the bearer token
    # @return [AppOnlyAuthenticator] a new authenticator
    # @example Create an app-only authenticator
    #   X::AppOnlyAuthenticator.new(api_key: "key", api_key_secret: "secret")
    def initialize(api_key:, api_key_secret:, bearer_token: nil, connection: Connection.new)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @bearer_token = bearer_token
      @connection = connection
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
    # @example Generate the header
    #   authenticator.header(request) # => {"Authorization" => "Bearer ..."}
    def header(_request)
      {AUTHENTICATION_HEADER => "Bearer #{bearer_token}"}
    end

    # The bearer token, fetched once with the API key and secret
    #
    # @api public
    # @return [String] the bearer token
    # @raise [AuthorizationError] if X refuses to issue the bearer token
    # @example Get the bearer token
    #   authenticator.bearer_token
    def bearer_token
      @mutex.synchronize { @bearer_token ||= fetch_bearer_token }
    end

    private

    # Exchange the API key and secret for a bearer token
    # @api private
    # @return [String] the bearer token
    # @raise [AuthorizationError] if the token endpoint rejects the request
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
