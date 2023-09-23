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

    def_delegators :@authenticator, :bearer_token, :api_key, :api_key_secret, :access_token, :access_token_secret
    def_delegators :@authenticator, :bearer_token=, :api_key=, :api_key_secret=, :access_token=, :access_token_secret=
    def_delegators :@connection, :base_uri, :open_timeout, :read_timeout, :write_timeout, :debug_output
    def_delegators :@connection, :base_uri=, :open_timeout=, :read_timeout=, :write_timeout=, :debug_output=
    def_delegators :@request_builder, :content_type, :user_agent
    def_delegators :@request_builder, :content_type=, :user_agent=
    def_delegators :@response_handler, :array_class, :object_class
    def_delegators :@response_handler, :array_class=, :object_class=

    def initialize(bearer_token: nil,
      api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      base_url: Connection::DEFAULT_BASE_URL,
      open_timeout: Connection::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Connection::DEFAULT_READ_TIMEOUT,
      write_timeout: Connection::DEFAULT_WRITE_TIMEOUT,
      proxy_url: nil,
      content_type: RequestBuilder::DEFAULT_CONTENT_TYPE,
      user_agent: RequestBuilder::DEFAULT_USER_AGENT,
      debug_output: nil,
      array_class: ResponseHandler::DEFAULT_ARRAY_CLASS,
      object_class: ResponseHandler::DEFAULT_OBJECT_CLASS,
      max_redirects: RedirectHandler::DEFAULT_MAX_REDIRECTS)

      initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @connection = Connection.new(base_url: base_url, open_timeout: open_timeout, read_timeout: read_timeout,
        write_timeout: write_timeout, debug_output: debug_output, proxy_url: proxy_url)
      @request_builder = RequestBuilder.new(content_type: content_type, user_agent: user_agent)
      @redirect_handler = RedirectHandler.new(@authenticator, @connection, @request_builder,
        max_redirects: max_redirects)
      @response_handler = ResponseHandler.new(array_class: array_class, object_class: object_class)
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

    def initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @authenticator = if bearer_token
        BearerTokenAuthenticator.new(bearer_token)
      elsif api_key && api_key_secret && access_token && access_token_secret
        OauthAuthenticator.new(api_key, api_key_secret, access_token, access_token_secret)
      else
        raise ArgumentError,
          "Client must be initialized with either a bearer_token or " \
          "an api_key, api_key_secret, access_token, and access_token_secret"
      end
    end

    def send_request(http_method, endpoint, body = nil)
      uri = URI.join(base_uri.to_s, endpoint)
      request = @request_builder.build(@authenticator, http_method, uri, body: body)
      response = @connection.send_request(request)
      final_response = @redirect_handler.handle_redirects(response, request, base_uri)
      @response_handler.handle(final_response)
    end
  end
end
