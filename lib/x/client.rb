require "forwardable"
require_relative "bearer_token_authenticator"
require_relative "connection"
require_relative "oauth_authenticator"
require_relative "redirect_handler"
require_relative "request_builder"
require_relative "response_parser"

module X
  # A client for interacting with the X API
  # @api public
  class Client
    extend Forwardable

    # Default base URL for the X API
    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    # Default class for parsing JSON arrays
    DEFAULT_ARRAY_CLASS = Array
    # Default class for parsing JSON objects
    DEFAULT_OBJECT_CLASS = Hash

    # The base URL for API requests
    # @api public
    # @return [String] the base URL for API requests
    # @example Get or set the base URL
    #   client.base_url = "https://api.x.com/2/"
    attr_accessor :base_url

    # The default class for parsing JSON arrays
    # @api public
    # @return [Class] the default class for parsing JSON arrays
    # @example Get or set the default array class
    #   client.default_array_class = Array
    attr_accessor :default_array_class

    # The default class for parsing JSON objects
    # @api public
    # @return [Class] the default class for parsing JSON objects
    # @example Get or set the default object class
    #   client.default_object_class = Hash
    attr_accessor :default_object_class

    # The API key for OAuth authentication
    # @api public
    # @return [String, nil] the API key for OAuth authentication
    # @example Get the API key
    #   client.api_key
    attr_reader :api_key

    # The API key secret for OAuth authentication
    # @api public
    # @return [String, nil] the API key secret for OAuth authentication
    # @example Get the API key secret
    #   client.api_key_secret
    attr_reader :api_key_secret

    # The access token for OAuth authentication
    # @api public
    # @return [String, nil] the access token for OAuth authentication
    # @example Get the access token
    #   client.access_token
    attr_reader :access_token

    # The access token secret for OAuth authentication
    # @api public
    # @return [String, nil] the access token secret for OAuth authentication
    # @example Get the access token secret
    #   client.access_token_secret
    attr_reader :access_token_secret

    # The bearer token for authentication
    # @api public
    # @return [String, nil] the bearer token for authentication
    # @example Get the bearer token
    #   client.bearer_token
    attr_reader :bearer_token

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects
    def_delegators :@redirect_handler, :max_redirects=

    # Initialize a new X API client
    #
    # @api public
    # @param api_key [String, nil] the API key for OAuth authentication
    # @param api_key_secret [String, nil] the API key secret for OAuth authentication
    # @param access_token [String, nil] the access token for OAuth authentication
    # @param access_token_secret [String, nil] the access token secret for OAuth authentication
    # @param bearer_token [String, nil] the bearer token for authentication
    # @param base_url [String] the base URL for API requests
    # @param open_timeout [Integer] the timeout for opening connections in seconds
    # @param read_timeout [Integer] the timeout for reading responses in seconds
    # @param write_timeout [Integer] the timeout for writing requests in seconds
    # @param debug_output [IO] the IO object for debug output
    # @param proxy_url [String, nil] the proxy URL for requests
    # @param default_array_class [Class] the default class for parsing JSON arrays
    # @param default_object_class [Class] the default class for parsing JSON objects
    # @param max_redirects [Integer] the maximum number of redirects to follow
    # @return [Client] a new client instance
    # @example Create a client with bearer token authentication
    #   client = X::Client.new(bearer_token: "token")
    # @example Create a client with OAuth authentication
    #   client = X::Client.new(
    #     api_key: "key",
    #     api_key_secret: "secret",
    #     access_token: "token",
    #     access_token_secret: "token_secret"
    #   )
    def initialize(api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      bearer_token: nil,
      base_url: DEFAULT_BASE_URL,
      open_timeout: Connection::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Connection::DEFAULT_READ_TIMEOUT,
      write_timeout: Connection::DEFAULT_WRITE_TIMEOUT,
      debug_output: Connection::DEFAULT_DEBUG_OUTPUT,
      proxy_url: nil,
      default_array_class: DEFAULT_ARRAY_CLASS,
      default_object_class: DEFAULT_OBJECT_CLASS,
      max_redirects: RedirectHandler::DEFAULT_MAX_REDIRECTS)
      initialize_oauth(api_key, api_key_secret, access_token, access_token_secret, bearer_token)
      initialize_authenticator
      @base_url = base_url
      initialize_default_classes(default_array_class, default_object_class)
      @connection = Connection.new(open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:)
      @request_builder = RequestBuilder.new
      @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
      @response_parser = ResponseParser.new
    end

    # Make a GET request to the API
    #
    # @api public
    # @param endpoint [String] the API endpoint
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    # @example Get user information
    #   client.get("users/me")
    def get(endpoint, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:get, endpoint, headers:, array_class:, object_class:)
    end

    # Make a POST request to the API
    #
    # @api public
    # @param endpoint [String] the API endpoint
    # @param body [String, nil] the request body
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    # @example Create a tweet
    #   client.post("tweets", '{"text": "Hello, world!"}')
    def post(endpoint, body = nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:post, endpoint, body:, headers:, array_class:, object_class:)
    end

    # Make a PUT request to the API
    #
    # @api public
    # @param endpoint [String] the API endpoint
    # @param body [String, nil] the request body
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    # @example Update a resource
    #   client.put("resource/123", '{"key": "value"}')
    def put(endpoint, body = nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:put, endpoint, body:, headers:, array_class:, object_class:)
    end

    # Make a DELETE request to the API
    #
    # @api public
    # @param endpoint [String] the API endpoint
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    # @example Delete a tweet
    #   client.delete("tweets/123")
    def delete(endpoint, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:delete, endpoint, headers:, array_class:, object_class:)
    end

    # Set the API key for OAuth authentication
    #
    # @api public
    # @param api_key [String] the API key
    # @return [void]
    # @example Set the API key
    #   client.api_key = "new_key"
    def api_key=(api_key)
      @api_key = api_key
      initialize_authenticator
    end

    # Set the API key secret for OAuth authentication
    #
    # @api public
    # @param api_key_secret [String] the API key secret
    # @return [void]
    # @example Set the API key secret
    #   client.api_key_secret = "new_secret"
    def api_key_secret=(api_key_secret)
      @api_key_secret = api_key_secret
      initialize_authenticator
    end

    # Set the access token for OAuth authentication
    #
    # @api public
    # @param access_token [String] the access token
    # @return [void]
    # @example Set the access token
    #   client.access_token = "new_token"
    def access_token=(access_token)
      @access_token = access_token
      initialize_authenticator
    end

    # Set the access token secret for OAuth authentication
    #
    # @api public
    # @param access_token_secret [String] the access token secret
    # @return [void]
    # @example Set the access token secret
    #   client.access_token_secret = "new_secret"
    def access_token_secret=(access_token_secret)
      @access_token_secret = access_token_secret
      initialize_authenticator
    end

    # Set the bearer token for authentication
    #
    # @api public
    # @param bearer_token [String] the bearer token
    # @return [void]
    # @example Set the bearer token
    #   client.bearer_token = "new_token"
    def bearer_token=(bearer_token)
      @bearer_token = bearer_token
      initialize_authenticator
    end

    private

    # Initialize OAuth credentials
    # @api private
    # @param api_key [String, nil] the API key
    # @param api_key_secret [String, nil] the API key secret
    # @param access_token [String, nil] the access token
    # @param access_token_secret [String, nil] the access token secret
    # @param bearer_token [String, nil] the bearer token
    # @return [void]
    def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret, bearer_token)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
      @bearer_token = bearer_token
    end

    # Initialize default classes for JSON parsing
    # @api private
    # @param default_array_class [Class] the default array class
    # @param default_object_class [Class] the default object class
    # @return [void]
    def initialize_default_classes(default_array_class, default_object_class)
      @default_array_class = default_array_class
      @default_object_class = default_object_class
    end

    # Initialize the authenticator based on available credentials
    # @api private
    # @return [void]
    def initialize_authenticator
      @authenticator = if api_key && api_key_secret && access_token && access_token_secret
        OAuthAuthenticator.new(api_key:, api_key_secret:, access_token:, access_token_secret:)
      elsif bearer_token
        BearerTokenAuthenticator.new(bearer_token:)
      elsif @authenticator.nil?
        Authenticator.new
      else
        @authenticator
      end
    end

    # Execute an HTTP request
    # @api private
    # @param http_method [Symbol] the HTTP method
    # @param endpoint [String] the API endpoint
    # @param body [String, nil] the request body
    # @param headers [Hash] additional headers
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    def execute_request(http_method, endpoint, body: nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      uri = URI.join(base_url, endpoint)
      request = @request_builder.build(http_method:, uri:, body:, headers:, authenticator: @authenticator)
      response = @connection.perform(request:)
      response = @redirect_handler.handle(response:, request:, base_url:, authenticator: @authenticator)
      @response_parser.parse(response:, array_class:, object_class:)
    end
  end
end
