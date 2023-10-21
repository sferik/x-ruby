require "net/http"
require "uri"
require_relative "errors/too_many_redirects"

module X
  # Handles HTTP redirects
  class RedirectHandler
    DEFAULT_MAX_REDIRECTS = 10

    attr_accessor :max_redirects
    attr_reader :authenticator, :connection, :request_builder

    def initialize(authenticator, connection, request_builder, max_redirects: DEFAULT_MAX_REDIRECTS)
      @authenticator = authenticator
      @connection = connection
      @request_builder = request_builder
      @max_redirects = max_redirects
    end

    def handle_redirects(response, request, base_url, redirect_count = 0)
      if response.is_a?(Net::HTTPRedirection)
        raise TooManyRedirects, "Too many redirects" if redirect_count > max_redirects

        new_uri = build_new_uri(response, base_url)

        new_request = build_request(request, new_uri, Integer(response.code))
        new_response = connection.send_request(new_request)

        handle_redirects(new_response, new_request, base_url, redirect_count + 1)
      else
        response
      end
    end

    private

    def build_new_uri(response, base_url)
      location = response.fetch("location")
      # If location is relative, it will join with the original base URL, otherwise it will overwrite it
      URI.join(base_url, location)
    end

    def build_request(request, new_uri, response_code)
      case response_code
      when 307, 308
        http_method = request.method.downcase.to_sym
        body = request.body
      else
        http_method = :get
      end

      request_builder.build(authenticator, http_method, new_uri, body: body)
    end
  end
end
