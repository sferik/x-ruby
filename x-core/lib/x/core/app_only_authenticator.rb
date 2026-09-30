# frozen_string_literal: true

require "simple_oauth"
require_relative "authenticator"
require_relative "connection"
require_relative "credential_validator"
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
    # The endpoint that exchanges an API key and secret for a bearer token, at X, whose path is requested at the
    # origin of the base URL of the client that takes the authenticator
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
    # @raise [ArgumentError] if the API key or secret is nil or empty, or the bearer token is empty
    # @example Create an app-only authenticator
    #   X::AppOnlyAuthenticator.new(api_key: "key", api_key_secret: "secret")
    def initialize(api_key:, api_key_secret:, bearer_token: nil)
      Core::CredentialValidator.validate_required!({api_key:, api_key_secret:}, {bearer_token:})
      @api_key = api_key
      @api_key_secret = api_key_secret
      @bearer_token = bearer_token
      @connection = Core::Connection.new
      @token_url = TOKEN_URL
      @mutex = Mutex.new
    end

    # Generate the authentication headers, fetching the bearer token first if needed
    #
    # @api public
    # @param _request [#method, #uri, #body, #[], nil] the request, which app-only authentication does not sign
    # @return [Hash{String => String}] the authorization header
    # @raise [AuthorizationError] if X refuses to issue the bearer token
    # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
    # @example Generate the header
    #   authenticator.headers(request) # => {"Authorization" => "Bearer ..."}
    def headers(_request)
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

    # Fetch the bearer token over the connection of the first client that takes it
    #
    # The token endpoint is requested at the scheme, host, and port of the base URL of the client, rather than of
    # TOKEN_URL, so that a client pointed at another host sends the API key and secret there, as it sends its
    # requests. A client that takes it after the first leaves it fetching over the connection of the first; see
    # {OAuth2Authenticator}. Internal to x-core: a client fetches the token of the authenticator it builds, or is
    # given, over its own connection, with its proxy, timeouts, and debug output, and calls it with __send__, since it
    # is private.
    #
    # @api private
    # @param connection [Core::Connection] the connection to fetch the token over
    # @param base_url [String] the base URL of the client, at whose origin the token endpoint is requested
    # @return [AppOnlyAuthenticator] the authenticator
    def token_requests_over(connection, base_url)
      @mutex.synchronize do
        unless @taken
          @connection = connection
          @token_url = Core::TokenEndpoint.url_at(base_url, TOKEN_URL)
        end
        @taken = true
      end
      self
    end

    # The API key secret, which buys the bearer token
    # @api private
    # @return [String] the API key secret
    # @example Buy a bearer token with the API key secret
    #   api_key_secret
    attr_reader :api_key_secret

    # Check whether a copy of a client, given these options, holds these credentials
    #
    # Internal to x-core: Client shares the authenticator with a copy that holds its API key and secret and was given
    # no bearer token, and calls it with __send__, since it is private.
    #
    # @api private
    # @param options [Hash] the options the copy was given in place of the client's
    # @return [Boolean] true if the options name no bearer token, and no API key or secret but the ones held
    def holds?(options)
      !options.key?(:bearer_token) && options.slice(:api_key, :api_key_secret) <= {api_key:, api_key_secret:}
    end

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
      raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE), cause: e.cause
    end

    # Build the client credentials request
    # @api private
    # @return [SimpleOAuth::OAuth2::Request] the token request
    def token_request
      SimpleOAuth::OAuth2::Client.new(client_id: api_key, client_secret: api_key_secret, token_endpoint: @token_url)
        .client_credentials_request
    end
  end
end
