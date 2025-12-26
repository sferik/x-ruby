require "forwardable"
require_relative "authenticator"
require_relative "bearer_token_authenticator"
require_relative "client_credentials"
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
    include ClientCredentials

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
    #   client.base_url = "https://api.twitter.com/1.1/"
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

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects
    def_delegators :@redirect_handler, :max_redirects=

    # Initialize a new X API client
    #
    # @api public
    # @param api_key [String, nil] the API key for OAuth 1.0a authentication
    # @param api_key_secret [String, nil] the API key secret for OAuth 1.0a authentication
    # @param access_token [String, nil] the access token for OAuth authentication
    # @param access_token_secret [String, nil] the access token secret for OAuth 1.0a authentication
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
    #   client = X::Client.new(bearer_token: "your_bearer_token")
    # @example Create a client with OAuth 1.0a authentication
    #   client = X::Client.new(api_key: "key", api_key_secret: "secret", access_token: "token", access_token_secret: "token_secret")
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
      initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:)
      initialize_authenticator
      @base_url = base_url
      @default_array_class = default_array_class
      @default_object_class = default_object_class
      @connection = Connection.new(open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:)
      @request_builder = RequestBuilder.new
      @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
      @response_parser = ResponseParser.new
    end

    # Perform a GET request to the X API
    #
    # @api public
    # @return [Hash, Array, nil] the parsed response body
    # @example Get a user by username
    #   client.get("users/by/username/sferik")
    def get(endpoint, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:get, endpoint, headers:, array_class:, object_class:)
    end

    # Perform a POST request to the X API
    #
    # @api public
    # @return [Hash, Array, nil] the parsed response body
    # @example Create a tweet
    #   client.post("tweets", '{"text": "Hello, World!"}')
    def post(endpoint, body = nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:post, endpoint, body:, headers:, array_class:, object_class:)
    end

    # Perform a PUT request to the X API
    #
    # @api public
    # @return [Hash, Array, nil] the parsed response body
    # @example Update a resource
    #   client.put("some/endpoint", '{"key": "value"}')
    def put(endpoint, body = nil, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:put, endpoint, body:, headers:, array_class:, object_class:)
    end

    # Perform a DELETE request to the X API
    #
    # @api public
    # @return [Hash, Array, nil] the parsed response body
    # @example Delete a tweet
    #   client.delete("tweets/1234567890")
    def delete(endpoint, headers: {}, array_class: default_array_class, object_class: default_object_class)
      execute_request(:delete, endpoint, headers:, array_class:, object_class:)
    end

    private

    # Execute an HTTP request to the X API
    # @api private
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
