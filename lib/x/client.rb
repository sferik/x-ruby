require "forwardable"
require_relative "bearer_token_authenticator"
require_relative "oauth_authenticator"
require_relative "connection"
require_relative "redirect_handler"
require_relative "request_builder"
require_relative "response_handler"

module X
  # Main public interface
  class Client
    extend Forwardable

    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze

    attr_accessor :base_url

    def_delegators :@authenticator, :bearer_token, :api_key, :api_key_secret, :access_token, :access_token_secret
    def_delegators :@authenticator, :bearer_token=, :api_key=, :api_key_secret=, :access_token=, :access_token_secret=
    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects
    def_delegators :@redirect_handler, :max_redirects=
    def_delegators :@response_handler, :array_class, :object_class
    def_delegators :@response_handler, :array_class=, :object_class=

    def initialize(bearer_token: nil,
      api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      base_url: DEFAULT_BASE_URL,
      open_timeout: Connection::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Connection::DEFAULT_READ_TIMEOUT,
      write_timeout: Connection::DEFAULT_WRITE_TIMEOUT,
      proxy_url: nil,
      debug_output: nil,
      array_class: nil,
      object_class: nil,
      max_redirects: RedirectHandler::DEFAULT_MAX_REDIRECTS)

      @base_url = base_url
      initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @connection = Connection.new(open_timeout: open_timeout, read_timeout: read_timeout,
        write_timeout: write_timeout, debug_output: debug_output, proxy_url: proxy_url)
      @request_builder = RequestBuilder.new
      @redirect_handler = RedirectHandler.new(@authenticator, @connection, @request_builder,
        max_redirects: max_redirects)
      @response_handler = ResponseHandler.new(array_class: array_class, object_class: object_class)
    end

    def get(endpoint, headers: {})
      send_request(:get, endpoint, headers: headers)
    end

    def post(endpoint, body = nil, headers: {})
      send_request(:post, endpoint, body: body, headers: headers)
    end

    def put(endpoint, body = nil, headers: {})
      send_request(:put, endpoint, body: body, headers: headers)
    end

    def delete(endpoint, headers: {})
      send_request(:delete, endpoint, headers: headers)
    end

    private

    def initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @authenticator = if bearer_token
        BearerTokenAuthenticator.new(bearer_token)
      elsif api_key && api_key_secret && access_token && access_token_secret
        OAuthAuthenticator.new(api_key, api_key_secret, access_token, access_token_secret)
      else
        raise ArgumentError, "Client must be initialized with either a bearer_token or " \
                             "an api_key, api_key_secret, access_token, and access_token_secret"
      end
    end

    def send_request(http_method, endpoint, headers:, body: nil)
      uri = URI.join(base_url, endpoint)
      request = @request_builder.build(@authenticator, http_method, uri, body: body, headers: headers)
      response = @connection.send_request(request)
      final_response = @redirect_handler.handle_redirects(response, request, base_url)
      @response_handler.handle(final_response)
    end
  end
end
