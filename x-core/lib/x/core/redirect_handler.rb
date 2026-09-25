# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "authenticator"
require_relative "connection"
require_relative "errors/too_many_redirects"
require_relative "origin"
require_relative "request_builder"
require_relative "setting_validator"

module X
  module Core
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
      attr_reader :max_redirects

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
      # @raise [ArgumentError] if the maximum number of redirects is not an Integer of at least 0
      # @example Create a redirect handler
      #   handler = X::Core::RedirectHandler.new(connection: conn, request_builder: builder)
      def initialize(connection: Connection.new, request_builder: RequestBuilder.new,
        max_redirects: DEFAULT_MAX_REDIRECTS)
        @connection = connection
        @request_builder = request_builder
        @max_redirects = SettingValidator.count!(:max_redirects, max_redirects)
      end

      # Handle redirects for an HTTP response
      #
      # A redirect to another scheme, host, or port drops the credentials, the authenticator's and any Authorization,
      # Cookie, or Proxy-Authorization header among the headers, as Origin decides; see {Origin}. A 307 or 308 keeps
      # the method and the body of the request, so a request whose body holds something private replays it to the
      # host it is redirected to, whatever its origin.
      #
      # A redirect that cannot be followed, such as 304 Not Modified or one whose location is missing, is not a
      # valid URL, or is not an HTTP or HTTPS URL, is returned as it is, so that the client raises an HTTPError for it,
      # however many redirects were followed before it. A redirect that can be followed once max_redirects have been
      # raises TooManyRedirects, so a max_redirects of 0 follows none, and raises for every one that could be.
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

        uri = request.uri #: URI::Generic
        new_uri = build_new_uri(response, uri)
        return response if new_uri.nil?
        raise TooManyRedirects, "Too many redirects" if redirect_count >= max_redirects

        authenticator, headers = Origin.credentials_for(from: uri, to: new_uri, authenticator:, headers:)
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
      # @return [URI::HTTP, nil] the new URI, or nil if the location is missing, invalid, or not an HTTP or HTTPS URL
      def build_new_uri(response, uri)
        location = response["location"] or return
        new_uri = URI.join(uri, location)
        new_uri if new_uri.is_a?(URI::HTTP)
      rescue URI::InvalidURIError
        nil
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
end
