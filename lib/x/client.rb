require "forwardable"
require "json"
require "net/http"
require "oauth"
require "uri"
require_relative "client/errors"
require_relative "version"

module X
  # HTTP client that handles authentication and requests
  class Client
    extend Forwardable

    attr_accessor :bearer_token, :content_type, :read_timeout, :user_agent, :array_class, :object_class
    attr_reader :base_url

    def_delegator :@access_token, :secret, :access_token_secret
    def_delegator :@access_token, :secret=, :access_token_secret=
    def_delegator :@access_token, :token, :access_token
    def_delegator :@access_token, :token=, :access_token=
    def_delegator :@consumer, :key, :api_key
    def_delegator :@consumer, :key=, :api_key=
    def_delegator :@consumer, :secret, :api_key_secret
    def_delegator :@consumer, :secret=, :api_key_secret=

    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    DEFAULT_CONTENT_TYPE = "application/json; charset=utf-8".freeze
    DEFAULT_ARRAY_CLASS = Array
    DEFAULT_OBJECT_CLASS = Hash
    DEFAULT_READ_TIMEOUT = 60 # seconds
    DEFAULT_USER_AGENT = "X-Client/#{Version} Ruby/#{RUBY_VERSION}".freeze

    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      base_url: DEFAULT_BASE_URL, content_type: DEFAULT_CONTENT_TYPE,
      read_timeout: DEFAULT_READ_TIMEOUT, user_agent: DEFAULT_USER_AGENT,
      array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @bearer_token = bearer_token
      self.base_url = base_url
      @content_type = content_type
      @read_timeout = read_timeout
      @user_agent = user_agent
      @array_class = array_class
      @object_class = object_class

      initialize_oauth(api_key, api_key_secret, access_token, access_token_secret) unless bearer_token
    end

    HTTP_METHODS.each_key do |http_method|
      define_method(http_method) do |endpoint, body = nil|
        send_request(http_method, endpoint, body)
      end
    end

    def base_url=(new_base_url)
      @base_url = URI(new_base_url)
      validate_base_url!
    end

    private

    def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      unless api_key && api_key_secret && access_token && access_token_secret
        raise ArgumentError, "Missing OAuth credentials"
      end

      @consumer = OAuth::Consumer.new(api_key, api_key_secret, site: @base_url)
      @access_token = OAuth::Token.new(access_token, access_token_secret)
    end

    def send_request(http_method, endpoint, body = nil)
      url = URI.join(@base_url, endpoint)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.read_timeout = @read_timeout

      request = create_request(http_method, url, body)
      add_headers(request)

      handle_response(http.request(request))
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e.message}"
    end

    def create_request(http_method, url, body)
      http_method_class = HTTP_METHODS[http_method]

      raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

      request = http_method_class.new(url)
      request.body = body if body && http_method != :get
      request
    end

    def add_headers(request)
      add_authorization(request)
      add_content_type(request)
      add_user_agent(request)
    end

    def add_authorization(request)
      if @bearer_token
        request["Authorization"] = "Bearer #{@bearer_token}"
      else
        @consumer.sign!(request, @access_token)
      end
    end

    def add_content_type(request)
      request["Content-Type"] = @content_type if @content_type
    end

    def add_user_agent(request)
      request["User-Agent"] = @user_agent if @user_agent
    end

    def validate_base_url!
      raise ArgumentError, "Invalid base URL" unless @base_url.is_a?(URI::HTTPS) || @base_url.is_a?(URI::HTTP)
    end

    def handle_response(response)
      ResponseHandler.new(response, @array_class, @object_class).handle
    end

    # HTTP client response handler
    class ResponseHandler
      def initialize(response, array_class, object_class)
        @response = response
        @array_class = array_class
        @object_class = object_class
      end

      def handle
        if successful_json_response?
          return JSON.parse(@response.body, array_class: @array_class,
            object_class: @object_class)
        end

        error_class = ERROR_CLASSES[@response.code.to_i] || Error
        error_message = "#{@response.code} #{@response.message}"
        raise error_class, error_message if @response.body.nil? || @response.body.empty?

        raise error_class.new(error_message, @response) # , error_message
      end

      private

      def successful_json_response?
        @response.is_a?(Net::HTTPSuccess) && @response.body && @response["content-type"] == DEFAULT_CONTENT_TYPE
      end
    end
  end
end
