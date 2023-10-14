require "net/http"
require "uri"
require_relative "version"

module X
  # Creates HTTP requests
  class RequestBuilder
    DEFAULT_HEADERS = {
      "Content-Type" => "application/json; charset=utf-8",
      "User-Agent" => "X-Client/#{VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
    }.freeze
    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def build(authenticator, http_method, uri, body: nil, headers: {})
      request = create_request(http_method, uri, body)
      add_headers(request, headers)
      add_authentication(request, authenticator)
      request
    end

    private

    def create_request(http_method, uri, body)
      http_method_class = HTTP_METHODS[http_method]

      raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

      escaped_uri = escape_query_params(uri)
      request = http_method_class.new(escaped_uri)
      request.body = body if body && http_method != :get
      request
    end

    def add_authentication(request, authenticator)
      authenticator.header(request).each do |key, value|
        request.add_field(key, value)
      end
    end

    def add_headers(request, headers)
      DEFAULT_HEADERS.merge(headers).each do |key, value|
        request.add_field(key, value)
      end
    end

    def escape_query_params(uri)
      URI(uri).tap { |u| u.query = URI.encode_www_form(URI.decode_www_form(uri.query)) if uri.query }
    end
  end
end
