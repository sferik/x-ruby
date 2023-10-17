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

    def handle_redirects(response, original_request, original_base_url, redirect_count = 0)
      if response.is_a?(Net::HTTPRedirection)
        raise TooManyRedirects.new("Too many redirects", response) if redirect_count >= max_redirects

        new_uri = build_new_uri(response, original_base_url)

        new_request = build_request(original_request, new_uri)
        new_response = connection.send_request(new_request)

        handle_redirects(new_response, new_request, original_base_url, redirect_count + 1)
      else
        response
      end
    end

    private

    def build_new_uri(response, original_base_url)
      location = response.fetch("location")
      new_uri = URI.parse(location)
      new_uri = URI.join(original_base_url, location) if new_uri.relative?
      new_uri
    end

    def build_request(original_request, new_uri)
      http_method = original_request.method.downcase.to_sym
      body = original_request.body if original_request.body
      request_builder.build(authenticator, http_method, new_uri, body: body)
    end
  end
end
