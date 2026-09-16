require "net/http"
require "uri"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/too_many_redirects"
require_relative "request_builder"

module X
  # Handles HTTP redirects for API requests
  #
  # Internal to x-core: Client follows redirects with it, and max_redirects is set on the client.
  #
  # @api private
  class RedirectHandler
    # Default maximum number of redirects to follow
    DEFAULT_MAX_REDIRECTS = 10

    # The maximum number of redirects to follow
    # @api private
    # @return [Integer] the maximum number of redirects to follow
    # @example Get or set the maximum redirects
    #   handler.max_redirects = 5
    attr_accessor :max_redirects

    # The connection for making requests
    # @api private
    # @return [Connection] the connection for making requests
    # @example Get the connection
    #   handler.connection
    attr_reader :connection

    # The request builder for creating requests
    # @api private
    # @return [RequestBuilder] the request builder for creating requests
    # @example Get the request builder
    #   handler.request_builder
    attr_reader :request_builder

    # Initialize a new RedirectHandler
    #
    # @api private
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
    # A redirect to another scheme, host, or port drops the credentials, the authenticator's and any
    # Authorization header among the headers, so that they never reach a host they were not meant for.
    #
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response to handle
    # @param request [Net::HTTPRequest] the request the response answers, built from a URI
    # @param headers [Hash] additional headers to send with redirected requests
    # @param authenticator [Authenticator] the authenticator for requests
    # @param redirect_count [Integer] the current redirect count
    # @return [Net::HTTPResponse] the final HTTP response after following redirects
    # @raise [TooManyRedirects] if the maximum number of redirects is exceeded
    # @example Handle a response
    #   response = handler.handle(response: resp, request: req)
    def handle(response:, request:, headers: {}, authenticator: Authenticator.new, redirect_count: 0)
      return response unless response.is_a?(Net::HTTPRedirection)
      raise TooManyRedirects, "Too many redirects" if redirect_count >= max_redirects

      uri = request.uri #: URI::Generic
      new_uri = build_new_uri(response, uri)
      authenticator, headers = credentials_for(uri, new_uri, authenticator, headers)
      new_request = build_request(request, new_uri, Integer(response.code), headers, authenticator)
      handle(response: connection.perform(request: new_request), request: new_request, headers:, authenticator:,
        redirect_count: redirect_count + 1)
    end

    private

    # Build a new URI from the redirect response
    #
    # A relative location is relative to the request that was redirected, as RFC 9110 Section 10.2.2 requires,
    # which need not share the base URL: a request can name a URL of its own.
    #
    # @api private
    # @param response [Net::HTTPResponse] the redirect response
    # @param uri [URI::Generic] the URI of the request that was redirected
    # @return [URI] the new URI
    def build_new_uri(response, uri)
      URI.join(uri, response.fetch("location"))
    end

    # The authenticator and headers of a redirect, dropping credentials off origin
    # @api private
    # @param from [URI::Generic] the URI of the request that was redirected
    # @param to [URI::Generic] the URI it was redirected to
    # @param authenticator [Authenticator] the authenticator of the request
    # @param headers [Hash{String => String}] the headers of the request
    # @return [Array(Authenticator, Hash{String => String})] the authenticator and headers
    def credentials_for(from, to, authenticator, headers)
      return [authenticator, headers] if same_origin?(from, to)

      [Authenticator.new, without_authorization(headers)]
    end

    # Check whether two URIs share a scheme, host, and port
    # @api private
    # @param uri [URI::Generic] the URI of the request that was redirected
    # @param other [URI::Generic] the URI it was redirected to
    # @return [Boolean] true if both have the same origin
    def same_origin?(uri, other) = origin(uri).eql?(origin(other))

    # The scheme, host, and port of a URI, in lowercase
    # @api private
    # @param uri [URI::Generic] the URI
    # @return [Array(String, String, Integer)] the origin
    def origin(uri)
      normalized = uri.normalize
      [normalized.scheme, normalized.host, normalized.port]
    end

    # Headers without an Authorization header, whatever its case
    # @api private
    # @param headers [Hash{String => String}] the headers
    # @return [Hash{String => String}] the headers other than Authorization
    def without_authorization(headers)
      headers.reject { |name, _| name.casecmp?(Authenticator::AUTHENTICATION_HEADER) }
    end

    # Build a new request for the redirect
    # @api private
    # @param request [Net::HTTPRequest] the original request
    # @param uri [URI] the new URI
    # @param response_code [Integer] the HTTP response code
    # @param headers [Hash] additional headers for the request
    # @param authenticator [Authenticator] the authenticator
    # @return [Net::HTTPRequest] the new request
    def build_request(request, uri, response_code, headers, authenticator)
      http_method = :get
      if [307, 308].include?(response_code)
        http_method = request.method.downcase.to_sym
        body = request.body
      end

      request_builder.build(http_method:, uri:, body:, headers:, authenticator:)
    end
  end
end
