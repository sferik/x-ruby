require "forwardable"
require "json"
require "uri"
require_relative "app_only_authenticator"
require_relative "authenticator"
require_relative "bearer_token_authenticator"
require_relative "client_credentials"
require_relative "connection"
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
    extend Forwardable
    include ClientCredentials
    include RequestEncoding

    # Default base URL for the X API
    DEFAULT_BASE_URL = "https://api.x.com/2/".freeze
    # Default class for parsing JSON arrays
    DEFAULT_ARRAY_CLASS = Array
    # Default class for parsing JSON objects
    DEFAULT_OBJECT_CLASS = Hash
    # Content type of a form-encoded request body
    FORM_CONTENT_TYPE = "application/x-www-form-urlencoded; charset=utf-8".freeze

    # The base URL for API requests
    # @api public
    # @return [String] the base URL for API requests
    # @example Get or set the base URL
    #   client.base_url = "https://api.x.com/1.1/"
    attr_accessor :base_url

    # The default class for parsing JSON arrays
    # @api public
    # @return [Class] the default class for parsing JSON arrays
    # @example Get or set the default array class
    #   client.default_array_class = Set
    attr_accessor :default_array_class

    # The default class for parsing JSON objects
    # @api public
    # @return [Class] the default class for parsing JSON objects
    # @example Get or set the default object class
    #   client.default_object_class = OpenStruct
    attr_accessor :default_object_class

    # The authenticator for API requests
    # @api public
    # @return [Authenticator] the authenticator instance
    # @example Check if the OAuth 2.0 token has expired
    #   client.authenticator.token_expired?
    attr_reader :authenticator

    # A callable passed an X::Response after each request and streamed object
    # @api public
    # @return [#call, nil] the callable, or nil for none
    # @example Total the resources a client reads
    #   client.on_response = ->(response) { total += response.resource_count }
    attr_accessor :on_response

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects, :max_redirects=
    def_delegators :@rate_limit_handler, :max_rate_limit_retries, :max_rate_limit_retries=, :max_rate_limit_wait, :max_rate_limit_wait=

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
    # @return [Client] a new client instance
    # @example Create a client with bearer token authentication
    #   client = X::Client.new(bearer_token: "your_bearer_token")
    # @example Create a client with OAuth 1.0a authentication
    #   client = X::Client.new(api_key: "key", api_key_secret: "secret", access_token: "token", access_token_secret: "token_secret")
    # @example Create a client that fetches an app-only bearer token with the API key and secret
    #   client = X::Client.new(api_key: "key", api_key_secret: "secret")
    # @example Create a client that retries a rate-limited request up to three times
    #   client = X::Client.new(bearer_token: "your_bearer_token", max_rate_limit_retries: 3)
    def initialize(api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      bearer_token: nil, client_id: nil, client_secret: nil, refresh_token: nil,
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
      on_response: nil)
      initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:, refresh_token:)
      initialize_authenticator
      @base_url = base_url
      initialize_response_handling(default_array_class:, default_object_class:, on_response:)
      @connection = Connection.new(open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:)
      initialize_handlers(max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:)
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
    # @api public
    # @param options [Hash] the options to change, as accepted by initialize
    # @return [Client] a new client with the same credentials and settings, apart from the options given
    # @example Derive an API v1.1 client
    #   v1_client = client.copy(base_url: "https://api.x.com/1.1/")
    # @example Derive an app-only client from the API key and secret
    #   app_client = client.copy(access_token: nil, access_token_secret: nil)
    def copy(**options)
      self.class.new(**credentials, **settings, **options)
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

    private

    # Initialize how responses are parsed and reported
    # @api private
    # @param default_array_class [Class] the default class for parsing JSON arrays
    # @param default_object_class [Class] the default class for parsing JSON objects
    # @param on_response [#call, nil] the callable passed an X::Response after every request and streamed object
    # @return [void]
    def initialize_response_handling(default_array_class:, default_object_class:, on_response:)
      @default_array_class = default_array_class
      @default_object_class = default_object_class
      @on_response = on_response
    end

    # Pass a response to on_response, if there is one
    # @api private
    # @param http_method [Symbol] the HTTP method of the request
    # @param uri [URI::Generic] the URI of the request
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [void]
    def report(http_method, uri, response)
      on_response&.call(Response.new(http_method, uri, response))
    end

    # Initialize the objects that build requests and handle responses
    # @api private
    # @param max_redirects [Integer] the maximum number of redirects to follow
    # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
    # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset
    # @return [void]
    def initialize_handlers(max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:)
      @request_builder = RequestBuilder.new
      @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
      @rate_limit_handler = RateLimitHandler.new(max_rate_limit_retries:, max_rate_limit_wait:)
      @response_parser = ResponseParser.new
    end

    # Execute an HTTP request to the X API
    # @api private
    # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
    def execute_request(http_method, endpoint, body: nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      uri = URI.join(base_url, endpoint_with(endpoint, params))
      headers = {"Content-Type" => FORM_CONTENT_TYPE}.merge(headers) unless form.nil?
      @rate_limit_handler.handle do
        request = @request_builder.build(http_method:, uri:, body: encode_body(body, form), headers:, authenticator:)
        response = @redirect_handler.handle(response: @connection.perform(request:), request:, base_url:, headers:, authenticator:)
        report(http_method, uri, response)
        @response_parser.parse(response:, array_class:, object_class:, client: self)
      end
    end

    # The settings other than credentials, as initialize accepts them
    # @api private
    # @return [Hash{Symbol => Object}] the settings
    def settings
      {base_url:, open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:, default_array_class:,
       default_object_class:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, on_response:}
    end
  end
end
