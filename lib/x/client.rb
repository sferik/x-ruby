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

    attr_reader :base_url
    attr_accessor :content_type, :open_timeout, :read_timeout, :user_agent, :array_class, :object_class

    def_delegators :@authenticator, :bearer_token, :api_key, :api_key_secret, :access_token, :access_token_secret
    def_delegators :@authenticator, :bearer_token=, :api_key=, :api_key_secret=, :access_token=, :access_token_secret=

    def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      base_url: DEFAULT_BASE_URL, content_type: DEFAULT_CONTENT_TYPE,
      open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, user_agent: DEFAULT_USER_AGENT,
      array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)

      @authenticator = Authenticator.new(bearer_token: bearer_token, api_key: api_key, api_key_secret: api_key_secret,
        access_token: access_token, access_token_secret: access_token_secret)
      self.base_url = base_url
      @content_type = content_type
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @user_agent = user_agent
      @array_class = array_class
      @object_class = object_class
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

    def base_url=(new_base_url)
      uri = URI(new_base_url)
      raise ArgumentError, "Invalid base URL" unless uri.is_a?(URI::HTTPS) || uri.is_a?(URI::HTTP)

      @base_url = uri
    end

    private

    def send_request(http_method, endpoint, body = nil)
      request = RequestBuilder.build(http_method, @base_url, endpoint, body)
      add_headers(request)

      response = Connection.send_request(@base_url, @open_timeout, @read_timeout, request)

      ResponseHandler.new(response, @array_class, @object_class).handle
    end

    def add_headers(request)
      add_authorization(request)
      add_content_type(request)
      add_user_agent(request)
    end

    def add_authorization(request)
      if @authenticator.bearer_token
        request["Authorization"] = "Bearer #{@bearer_token}"
      else
        @authenticator.sign!(request)
      end
    end

    def add_content_type(request)
      request["Content-Type"] = @content_type if @content_type
    end

    def add_user_agent(request)
      request["User-Agent"] = @user_agent if @user_agent
    end
  end
end
