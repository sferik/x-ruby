require "forwardable"
require "json"
require "net/http"
require "oauth"
require "uri"
require_relative "version"

module X
  class Error < ::StandardError; end
  class NetworkError < Error; end
  class ClientError < Error; end
  class AuthenticationError < ClientError; end
  class BadRequestError < ClientError; end
  class ForbiddenError < ClientError; end
  class NotFoundError < ClientError; end
  class TooManyRequestsError < ClientError; end
  class ServerError < Error; end
  class ServiceUnavailableError < ServerError; end

  # HTTP client that handles authentication and requests
  class Client
    extend Forwardable

    attr_accessor :bearer_token, :user_agent, :read_timeout
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
    DEFAULT_USER_AGENT = "X-Client/#{X::Version} Ruby/#{RUBY_VERSION}".freeze
    DEFAULT_READ_TIMEOUT = 60 # seconds
    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
                   base_url: DEFAULT_BASE_URL, user_agent: DEFAULT_USER_AGENT, read_timeout: DEFAULT_READ_TIMEOUT)
      @base_url = URI(base_url)
      @user_agent = user_agent
      @read_timeout = read_timeout

      validate_base_url!

      if bearer_token.nil?
        initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      else
        @bearer_token = bearer_token
      end
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

    def base_url=(base_url)
      @base_url = URI(base_url)
      validate_base_url!
    end

    private

    def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      unless api_key && api_key_secret && access_token && access_token_secret
        raise ArgumentError, "Missing OAuth credentials."
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
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
      raise X::NetworkError, "Network error: #{e.message}"
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
      if @bearer_token.nil?
        @consumer.sign!(request, @access_token)
      else
        request["Authorization"] = "Bearer #{@bearer_token}"
      end
    end

    def add_content_type(request)
      request["Content-Type"] = "application/json"
    end

    def add_user_agent(request)
      request["User-Agent"] = @user_agent if @user_agent
    end

    def validate_base_url!
      raise ArgumentError, "Invalid base URL" unless @base_url.is_a?(URI::HTTPS) || @base_url.is_a?(URI::HTTP)
    end

    def handle_response(response)
      ResponseHandler.new(response).handle
    end

    # HTTP client response handler
    class ResponseHandler
      ERROR_CLASSES = {
        400 => X::BadRequestError,
        401 => X::AuthenticationError,
        403 => X::ForbiddenError,
        404 => X::NotFoundError,
        429 => X::TooManyRequestsError,
        500 => X::ServerError,
        503 => X::ServiceUnavailableError
      }.freeze

      def initialize(response)
        @response = response
      end

      def handle
        return JSON.parse(@response.body) if @response.is_a?(Net::HTTPSuccess)

        error_class = ERROR_CLASSES[@response.code.to_i] || X::Error
        raise error_class, "#{error_class.name.split("::").last}: #{@response.code} #{@response.message}"
      end
    end
  end
end
