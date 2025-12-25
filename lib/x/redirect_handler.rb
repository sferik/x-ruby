require "net/http"
require "uri"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/too_many_redirects"
require_relative "request_builder"

module X
  # Handles HTTP redirects for API requests
  # @api public
  class RedirectHandler
    # Default maximum number of redirects to follow
    DEFAULT_MAX_REDIRECTS = 10

    # The maximum number of redirects to follow
    # @api public
    # @return [Integer] the maximum number of redirects to follow
    # @example Get or set the maximum redirects
    #   handler.max_redirects = 5
    attr_accessor :max_redirects

    # The connection for making requests
    # @api public
    # @return [Connection] the connection for making requests
    # @example Get the connection
    #   handler.connection
    attr_reader :connection

    # The request builder for creating requests
    # @api public
    # @return [RequestBuilder] the request builder for creating requests
    # @example Get the request builder
    #   handler.request_builder
    attr_reader :request_builder

    # Initialize a new RedirectHandler
    #
    # @api public
    # @param connection [Connection] the connection for making requests
    # @param request_builder [RequestBuilder] the request builder for creating requests
    # @param max_redirects [Integer] the maximum number of redirects to follow
    # @return [RedirectHandler] a new instance
    # @example Create a redirect handler
    #   handler = X::RedirectHandler.new(connection: conn, request_builder: builder)
    def initialize(connection: Connection.new, request_builder: RequestBuilder.new,
      max_redirects: DEFAULT_MAX_REDIRECTS)
      @connection = connection
      @request_builder = request_builder
      @max_redirects = max_redirects
    end

    # Handle redirects for an HTTP response
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response to handle
    # @param request [Net::HTTPRequest] the original HTTP request
    # @param base_url [String] the base URL for the request
    # @param authenticator [Authenticator] the authenticator for requests
    # @param redirect_count [Integer] the current redirect count
    # @return [Net::HTTPResponse] the final HTTP response after following redirects
    # @raise [TooManyRedirects] if the maximum number of redirects is exceeded
    # @example Handle a response
    #   response = handler.handle(response: resp, request: req, base_url: url)
    def handle(response:, request:, base_url:, authenticator: Authenticator.new, redirect_count: 0)
      if response.is_a?(Net::HTTPRedirection)
        raise TooManyRedirects, "Too many redirects" if redirect_count > max_redirects

        new_uri = build_new_uri(response, base_url)

        new_request = build_request(request, new_uri, Integer(response.code), authenticator)
        new_response = connection.perform(request: new_request)

        handle(response: new_response, request: new_request, base_url:, redirect_count: redirect_count + 1)
      else
        response
      end
    end

    private

    # Build a new URI from the redirect response
    # @api private
    # @param response [Net::HTTPResponse] the redirect response
    # @param base_url [String] the base URL
    # @return [URI] the new URI
    def build_new_uri(response, base_url)
      location = response.fetch("location")
      # If location is relative, it will join with the original base URL, otherwise it will overwrite it
      URI.join(base_url, location)
    end

    # Build a new request for the redirect
    # @api private
    # @param request [Net::HTTPRequest] the original request
    # @param uri [URI] the new URI
    # @param response_code [Integer] the HTTP response code
    # @param authenticator [Authenticator] the authenticator
    # @return [Net::HTTPRequest] the new request
    def build_request(request, uri, response_code, authenticator)
      http_method = :get
      if [307, 308].include?(response_code)
        http_method = request.method.downcase.to_sym
        body = request.body
      end

      request_builder.build(http_method:, uri:, body:, authenticator:)
    end
  end
end
