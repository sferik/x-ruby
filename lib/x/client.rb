require "json"
require "net/http"
require "oauth"

module X
  # HTTP client that handles authentication and requests
  class Client
    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    DEFAULT_USER_AGENT = "X-Client/#{VERSION} Ruby/#{RUBY_VERSION}".freeze

    def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
                   base_url: DEFAULT_BASE_URL, user_agent: DEFAULT_USER_AGENT)
      @http_request = HttpRequest.new(bearer_token: bearer_token,
                                      api_key: api_key,
                                      api_key_secret: api_key_secret,
                                      access_token: access_token,
                                      access_token_secret: access_token_secret,
                                      base_url: base_url,
                                      user_agent: user_agent)
    end

    def get(endpoint)
      handle_response { @http_request.get(endpoint) }
    end

    def post(endpoint, body = nil)
      handle_response { @http_request.post(endpoint, body) }
    end

    def put(endpoint, body = nil)
      handle_response { @http_request.put(endpoint, body) }
    end

    def delete(endpoint)
      handle_response { @http_request.delete(endpoint) }
    end

    private

    def handle_response
      response = yield
      ErrorHandler.new(response).handle
    end

    # HTTP client requester
    class HttpRequest
      HTTP_METHODS = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }.freeze

      def initialize(bearer_token: nil, api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
                     base_url: nil, user_agent: nil)
        @base_url = base_url
        @use_bearer_token = !bearer_token.nil?
        @user_agent = user_agent || Client::DEFAULT_USER_AGENT

        if @use_bearer_token
          @bearer_token = bearer_token
        else
          initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
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

      private

      def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
        unless api_key && api_key_secret && access_token && access_token_secret
          raise ArgumentError, "Missing OAuth credentials."
        end

        @consumer = OAuth::Consumer.new(api_key, api_key_secret, site: @base_url)
        @access_token = OAuth::Token.new(access_token, access_token_secret)
      end

      def send_request(http_method, endpoint, body = nil)
        url = URI.parse(@base_url + endpoint)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = create_request(http_method, url, body)
        add_authorization(request)
        add_user_agent(request)

        http.request(request)
      end

      def create_request(http_method, url, body)
        http_method_class = HTTP_METHODS[http_method]

        raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

        request = http_method_class.new(url)
        request.body = body if body && http_method != :get
        request
      end

      def add_authorization(request)
        if @use_bearer_token
          request["Authorization"] = "Bearer #{@bearer_token}"
        else
          @consumer.sign!(request, @access_token)
        end
      end

      def add_user_agent(request)
        request["User-Agent"] = @user_agent if @user_agent
      end
    end

    # HTTP client error handler
    class ErrorHandler
      HTTP_STATUS_HANDLERS = {
        Net::HTTPOK => :handle_success_response,
        Net::HTTPBadRequest => :handle_bad_request_response,
        Net::HTTPForbidden => :handle_forbidden_response,
        Net::HTTPUnauthorized => :handle_unauthorized_response,
        Net::HTTPNotFound => :handle_not_found_response,
        Net::HTTPTooManyRequests => :handle_too_many_requests_response,
        Net::HTTPInternalServerError => :handle_server_error_response,
        Net::HTTPServiceUnavailable => :handle_service_unavailable_response
      }.freeze

      def initialize(response)
        @response = response
      end

      def handle
        handler_method = HTTP_STATUS_HANDLERS[@response.class]
        if handler_method
          send(handler_method)
        else
          handle_unexpected_response
        end
      end

      private

      def handle_success_response
        JSON.parse(@response.body)
      end

      def handle_bad_request_response
        raise X::BadRequestError, "Bad request: #{@response.code} #{@response.message}"
      end

      def handle_forbidden_response
        raise X::ForbiddenError, "Forbidden: #{@response.code} #{@response.message}"
      end

      def handle_unauthorized_response
        raise X::AuthenticationError, "Authentication failed. Please check your credentials."
      end

      def handle_not_found_response
        raise X::NotFoundError, "Not found: #{@response.code} #{@response.message}"
      end

      def handle_too_many_requests_response
        raise X::TooManyRequestsError, "Too many requests: #{@response.code} #{@response.message}"
      end

      def handle_server_error_response
        raise X::ServerError, "Internal server error: #{@response.code} #{@response.message}"
      end

      def handle_service_unavailable_response
        raise X::ServiceUnavailableError, "Service unavailable: #{@response.code} #{@response.message}"
      end

      def handle_unexpected_response
        raise X::Error, "Unexpected response: #{@response.code}"
      end
    end
  end
end
