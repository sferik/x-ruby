require "forwardable"
require_relative "authenticator"
require_relative "client_defaults"
require_relative "connection"
require_relative "request_builder"
require_relative "response_handler"

module X
  # Main public interface
  class Client
    extend Forwardable
    include ClientDefaults

    def_delegators :@authenticator, :api_key, :api_key_secret, :access_token, :access_token_secret
    def_delegators :@authenticator, :api_key=, :api_key_secret=, :access_token=, :access_token_secret=
    def_delegators :@connection, :base_url, :open_timeout, :read_timeout, :write_timeout, :debug_output
    def_delegators :@connection, :base_url=, :open_timeout=, :read_timeout=, :write_timeout=, :debug_output=
    def_delegators :@request_builder, :content_type, :user_agent
    def_delegators :@request_builder, :content_type=, :user_agent=
    def_delegators :@response_handler, :array_class, :object_class
    def_delegators :@response_handler, :array_class=, :object_class=

    def initialize(api_key:, api_key_secret:, access_token:, access_token_secret:,
      base_url: DEFAULT_BASE_URL, content_type: DEFAULT_CONTENT_TYPE, user_agent: DEFAULT_USER_AGENT,
      open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, write_timeout: DEFAULT_WRITE_TIMEOUT,
      debug_output: nil, array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @authenticator = Authenticator.new(api_key, api_key_secret, access_token, access_token_secret)
      @connection = Connection.new(base_url, open_timeout, read_timeout, write_timeout, debug_output: debug_output)
      @request_builder = RequestBuilder.new(content_type, user_agent)
      @response_handler = ResponseHandler.new(array_class, object_class)
    end

    def get(endpoint)
      send_request(:get, endpoint)
    end

    def post(endpoint, body = nil)
      send_request(:post, endpoint, body)
    end

    def put(endpoint, body = nil)
      send_request(:put, endpoint, body)
    end

    def delete(endpoint)
      send_request(:delete, endpoint)
    end

    private

    def send_request(http_method, endpoint, body = nil)
      request = @request_builder.build(@authenticator, http_method, base_url, endpoint, body: body)
      response = @connection.send_request(request)
      @response_handler.handle(response)
    end
  end
end
