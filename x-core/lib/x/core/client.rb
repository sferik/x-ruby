require "json"
require "uri"
require_relative "app_only_authenticator"
require_relative "authenticator"
require_relative "bearer_token_authenticator"
require_relative "client_credentials"
require_relative "client_settings"
require_relative "connection"
require_relative "credential_validator"
require_relative "oauth1_authenticator"
require_relative "oauth2_authenticator"
require_relative "rate_limit_handler"
require_relative "redirect_handler"
require_relative "request_builder"
require_relative "request_encoding"
require_relative "response"
require_relative "response_parser"
require_relative "streaming_client"

module X
  # A client for interacting with the X API
  # @api public
  class Client
    include ClientCredentials
    include ClientSettings
    include RequestEncoding

    # Default base URL for the X API
    DEFAULT_BASE_URL = "https://api.x.com/2/".freeze
    # Default class for parsing JSON arrays
    DEFAULT_ARRAY_CLASS = Array
    # Default class for parsing JSON objects
    DEFAULT_OBJECT_CLASS = Hash
    # Content type of a form-encoded request body
    FORM_CONTENT_TYPE = "application/x-www-form-urlencoded; charset=utf-8".freeze

    # The authenticator for API requests
    # @api public
    # @return [Authenticator] the authenticator instance
    # @example Check if the OAuth 2.0 token has expired
    #   client.authenticator.token_expired?
    attr_reader :authenticator

    # A callable passed the OAuth 2.0 authenticator after each refresh
    # @api public
    # @return [#call, nil] the callable, or nil for none
    # @example Store the tokens of each refresh
    #   client.on_token_refresh = ->(auth) { store.save(auth.access_token, auth.refresh_token, auth.expires_at) }
    attr_accessor :on_token_refresh

    # Initialize a new X API client
    #
    # @api public
    # @param api_key [String, nil] the API key for OAuth 1.0a authentication
    # @param api_key_secret [String, nil] the API key secret for OAuth 1.0a authentication
    # @param access_token [String, nil] the access token for OAuth authentication
    # @param access_token_secret [String, nil] the access token secret for OAuth 1.0a authentication
    # @param bearer_token [String, nil] the bearer token for authentication
    # @param client_id [String, nil] the OAuth 2.0 client ID
    # @param client_secret [String, nil] the OAuth 2.0 client secret
    # @param refresh_token [String, nil] the OAuth 2.0 refresh token
    # @param expires_at [Time, nil] the time the OAuth 2.0 access token expires, after which a request refreshes it
    # @param base_url [String] the base URL for API requests
    # @param open_timeout [Integer] the timeout for opening connections in seconds
    # @param read_timeout [Integer] the timeout for reading responses in seconds
    # @param write_timeout [Integer] the timeout for writing requests in seconds
    # @param debug_output [IO] the IO object for debug output
    # @param proxy_url [String, nil] the proxy URL for requests
    # @param default_array_class [Class] the default class for parsing JSON arrays
    # @param default_object_class [Class] the default class for parsing JSON objects
    # @param max_redirects [Integer] the maximum number of redirects to follow
    # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit,
    #   after waiting for the limit to reset
    # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset; a request
    #   whose limit resets later raises TooManyRequests at once
    # @param on_response [#call, nil] a callable passed an X::Response after every request, failed ones included, and
    #   every object a stream delivers
    # @param on_token_refresh [#call, nil] a callable passed the OAuth 2.0 authenticator after each refresh, to store
    #   its new tokens
    # @return [Client] a new client instance
    # @raise [ArgumentError] if credentials are given that do not form a complete set, which would send requests
    #   without them, or authenticate as the app rather than a user
    # @raise [ArgumentError] if expires_at is neither a Time nor nil
    # @example Create a client with bearer token authentication
    #   client = X::Client.new(bearer_token: "your_bearer_token")
    # @example Create a client with OAuth 2.0 authentication that stores the tokens of each refresh
    #   client = X::Client.new(client_id: "id", client_secret: "secret", access_token: "token", refresh_token: "refresh",
    #     expires_at: Time.now + 7200, on_token_refresh: ->(auth) { store.save(auth.refresh_token) })
    # @example Create a client with OAuth 1.0a authentication
    #   client = X::Client.new(api_key: "key", api_key_secret: "secret", access_token: "token", access_token_secret: "token_secret")
    # @example Create a client that fetches an app-only bearer token with the API key and secret
    #   client = X::Client.new(api_key: "key", api_key_secret: "secret")
    # @example Create a client that retries a rate-limited request up to three times
    #   client = X::Client.new(bearer_token: "your_bearer_token", max_rate_limit_retries: 3)
    def initialize(api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      bearer_token: nil, client_id: nil, client_secret: nil, refresh_token: nil, expires_at: nil,
      base_url: DEFAULT_BASE_URL,
      open_timeout: Connection::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Connection::DEFAULT_READ_TIMEOUT,
      write_timeout: Connection::DEFAULT_WRITE_TIMEOUT,
      debug_output: nil,
      proxy_url: nil,
      default_array_class: DEFAULT_ARRAY_CLASS,
      default_object_class: DEFAULT_OBJECT_CLASS,
      max_redirects: RedirectHandler::DEFAULT_MAX_REDIRECTS,
      max_rate_limit_retries: RateLimitHandler::DEFAULT_MAX_RETRIES,
      max_rate_limit_wait: RateLimitHandler::DEFAULT_MAX_WAIT,
      on_response: nil,
      on_token_refresh: nil)
      @connection = Connection.new(open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:)
      @request_builder = RequestBuilder.new
      @response_parser = ResponseParser.new
      initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:, refresh_token:, expires_at:)
      @on_token_refresh = on_token_refresh
      initialize_authenticator
      CredentialValidator.validate!(authenticator, credentials)
      initialize_settings(base_url:, default_array_class:, default_object_class:, on_response:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:)
    end

    # Summarize the client for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name, base URL, and authenticator
    # @example Inspect a client
    #   client.inspect # => #<X::Client base_url="https://api.x.com/2/" authenticator=#<X::BearerTokenAuthenticator>>
    def inspect
      "#<#{self.class} base_url=#{base_url.inspect} authenticator=#{authenticator.inspect}>"
    end

    # Copy the client with some of its options changed
    #
    # A copy with the same OAuth 2.0 credentials shares the client's authenticator, so that a refresh by either
    # client reaches the other, since X accepts a refresh token once.
    #
    # @api public
    # @param options [Hash] the options to change, as accepted by initialize
    # @return [Client] a new client with the same credentials and settings, apart from the options given
    # @example Derive an API v1.1 client
    #   v1_client = client.copy(base_url: "https://api.x.com/1.1/")
    # @example Derive an app-only client from the API key and secret
    #   app_client = client.copy(access_token: nil, access_token_secret: nil)
    def copy(**options)
      self.class.new(**credentials, **settings, **options).tap { |copy| copy.share_authenticator(authenticator) }
    end

    # Perform a GET request to the X API
    #
    # @api public
    # @param endpoint [String] the endpoint, with or without a query string
    # @param params [Hash, nil] query parameters appended to the endpoint; nil values are dropped and arrays are joined with commas
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    # @example Get a user by username
    #   client.get("users/by/username/sferik")
    # @example Get users by identifier, requesting only some fields
    #   client.get("users", params: {ids: [1, 2], "user.fields": %w[id username]})
    def get(endpoint, params: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:get, endpoint, params:, headers:, array_class:, object_class:)
    end

    # Perform a POST request to the X API
    #
    # @api public
    # @param endpoint [String] the endpoint, with or without a query string
    # @param body [String, Hash, nil] the request body; a Hash is encoded as JSON
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @param form [Hash, nil] fields to send as a form-encoded body instead of the body
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    # @example Create a post
    #   client.post("tweets", {text: "Hello, World!"})
    # @example Post a form to the v1.1 API
    #   v1_client.post("account/settings.json", form: {lang: "en"})
    def post(endpoint, body = nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:post, endpoint, body:, params:, form:, headers:, array_class:, object_class:)
    end

    # Perform a PUT request to the X API
    #
    # @api public
    # @param endpoint [String] the endpoint, with or without a query string
    # @param body [String, Hash, nil] the request body; a Hash is encoded as JSON
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @param form [Hash, nil] fields to send as a form-encoded body instead of the body
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    # @example Update a resource
    #   client.put("some/endpoint", {key: "value"})
    def put(endpoint, body = nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:put, endpoint, body:, params:, form:, headers:, array_class:, object_class:)
    end

    # Perform a DELETE request to the X API
    #
    # @api public
    # @param endpoint [String] the endpoint, with or without a query string
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    # @example Delete a post
    #   client.delete("tweets/1234567890")
    def delete(endpoint, params: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:delete, endpoint, params:, headers:, array_class:, object_class:)
    end

    # A client for the streaming endpoints, which reads and reconnects differently
    #
    # @api public
    # @param options [Hash] the options of {StreamingClient#initialize}, such as read_timeout and max_reconnects
    # @return [StreamingClient] a streaming client that shares this client's credentials and settings
    # @example Stream filtered posts, giving up after five reconnects in a row
    #   client.streaming(max_reconnects: 5).stream("tweets/search/stream") { |post| puts post }
    def streaming(**options)
      StreamingClient.new(self, **options)
    end

    protected

    # Share an OAuth 2.0 authenticator that holds the same credentials
    #
    # A refresh by either client then reaches both. X accepts a refresh token once, so a copy that refreshed with
    # an authenticator of its own would leave the original client with a refresh token that no longer works.
    #
    # @api private
    # @param other [Authenticator] the authenticator of the client this one was copied from
    # @return [void]
    def share_authenticator(other)
      current = oauth2_authenticator_in_use
      return unless current && other.is_a?(OAuth2Authenticator)
      return unless oauth2_credentials_of(current).eql?(oauth2_credentials_of(other))

      @authenticator = other
    end

    # The OAuth 2.0 authenticator, if the client authenticates with one
    # @api private
    # @return [OAuth2Authenticator, nil] the authenticator or nil
    def oauth2_authenticator_in_use
      current = @authenticator
      current if current.is_a?(OAuth2Authenticator)
    end

    # Build an OAuth 2.0 authenticator on the client's connection, given credentials
    #
    # A public client has no client secret, and refreshes its tokens with its client ID alone.
    #
    # @api private
    # @return [OAuth2Authenticator, nil] the OAuth 2.0 authenticator or nil
    def oauth2_authenticator
      client_id = @client_id
      access_token = @access_token
      refresh_token = @refresh_token
      return unless client_id && access_token && refresh_token

      OAuth2Authenticator.new(client_id:, client_secret: @client_secret, access_token:, refresh_token:, expires_at: @expires_at,
        connection: @connection, on_refresh: ->(authenticator) { on_token_refresh&.call(authenticator) })
    end

    private

    # The credentials an OAuth 2.0 authenticator holds
    # @api private
    # @param authenticator [OAuth2Authenticator] the authenticator
    # @return [Array<String, Time, nil>] the client ID and secret, the tokens, and the expiration time
    def oauth2_credentials_of(authenticator)
      [authenticator.client_id, authenticator.client_secret, authenticator.access_token, authenticator.refresh_token,
        authenticator.expires_at]
    end

    # Run a request, again if a refresh replaces an OAuth 2.0 token the API rejects
    # @api private
    # @yield runs the request
    # @return [Object] what the block returns
    def refreshing_rejected_token(&)
      current = oauth2_authenticator_in_use
      current.nil? ? yield : current.retrying_rejected_token(&)
    end

    # Execute an HTTP request to the X API
    # @api private
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    def execute_request(http_method, endpoint, body: nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      uri = URI.join(base_url, endpoint_with(endpoint, params))
      headers = {"Content-Type" => FORM_CONTENT_TYPE}.merge(headers) unless form.nil?
      @rate_limit_handler.handle do
        refreshing_rejected_token do
          perform(http_method, uri, body: encode_body(body, form), headers:, array_class:, object_class:)
        end
      end
    end

    # Perform a request once, following redirects and parsing the response
    # @api private
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    def perform(http_method, uri, body:, headers:, array_class:, object_class:)
      request = @request_builder.build(http_method:, uri:, body:, headers:, authenticator:)
      response = @redirect_handler.handle(response: @connection.perform(request:), request:, headers:, authenticator:)
      report(http_method, uri, response)
      @response_parser.parse(response:, array_class:, object_class:, client: self)
    end
  end
end
