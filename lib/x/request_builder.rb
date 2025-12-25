require "net/http"
require "uri"
require_relative "authenticator"
require_relative "version"

module X
  # Builds HTTP requests for the X API
  # @api public
  class RequestBuilder
    # Default headers for API requests
    DEFAULT_HEADERS = {
      "Content-Type" => "application/json; charset=utf-8",
      "User-Agent" => "X-Client/#{VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
    }.freeze
    # Mapping of HTTP method symbols to Net::HTTP classes
    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    # Build an HTTP request
    #
    # @api public
    # @param http_method [Symbol] the HTTP method (:get, :post, :put, :delete)
    # @param uri [URI] the request URI
    # @param body [String, nil] the request body
    # @param headers [Hash] additional headers for the request
    # @param authenticator [Authenticator] the authenticator for the request
    # @return [Net::HTTPRequest] the built HTTP request
    # @raise [ArgumentError] if the HTTP method is not supported
    # @example Build a GET request
    #   builder.build(http_method: :get, uri: URI("https://api.x.com/2/users/me"))
    def build(http_method:, uri:, body: nil, headers: {}, authenticator: Authenticator.new)
      request = create_request(http_method:, uri:, body:)
      add_headers(request:, headers:)
      add_authentication(request:, authenticator:)
      request
    end

    private

    # Create an HTTP request
    # @api private
    # @param http_method [Symbol] the HTTP method
    # @param uri [URI] the request URI
    # @param body [String, nil] the request body
    # @return [Net::HTTPRequest] the created request
    def create_request(http_method:, uri:, body:)
      http_method_class = HTTP_METHODS[http_method]

      raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

      escaped_uri = escape_query_params(uri)
      request = http_method_class.new(escaped_uri)
      request.body = body
      request
    end

    # Add authentication to a request
    # @api private
    # @param request [Net::HTTPRequest] the request
    # @param authenticator [Authenticator] the authenticator
    # @return [void]
    def add_authentication(request:, authenticator:)
      authenticator.header(request).each do |key, value|
        request[key] = value
      end
    end

    # Add headers to a request
    # @api private
    # @param request [Net::HTTPRequest] the request
    # @param headers [Hash] additional headers
    # @return [void]
    def add_headers(request:, headers:)
      DEFAULT_HEADERS.merge(headers).each do |key, value|
        request[key] = value
      end
    end

    # Escape query parameters in a URI
    # @api private
    # @param uri [URI] the URI
    # @return [URI] the URI with escaped query parameters
    def escape_query_params(uri)
      URI(uri).tap do |u|
        u.query = URI.encode_www_form(URI.decode_www_form(u.query)).gsub("%2C", ",") if u.query
      end
    end
  end
end
