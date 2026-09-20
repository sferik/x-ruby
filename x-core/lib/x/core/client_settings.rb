# frozen_string_literal: true

require "forwardable"
require_relative "rate_limit_handler"
require_relative "redirect_handler"
require_relative "response"

module X
  module Core
    # The settings of a client other than its credentials: its base URL, parsing classes, hook, and the settings of
    # its connection and handlers, included into Client
    # @api private
    module ClientSettings
      extend Forwardable

      # The base URL for API requests
      # @api public
      # @return [String] the base URL for API requests, which ends with a slash
      # @example Get the base URL
      #   client.base_url # => "https://api.x.com/2/"
      attr_reader :base_url

      # The default class for parsing JSON arrays
      # @api public
      # @return [Class] the default class for parsing JSON arrays
      # @example Get or set the default array class
      #   client.default_array_class = Set
      attr_accessor :default_array_class

      # The default class for parsing JSON objects
      # @api public
      # @return [Class] the default class for parsing JSON objects
      # @example Get or set the default object class
      #   client.default_object_class = OpenStruct
      attr_accessor :default_object_class

      # A callable passed an X::Response after each request and streamed object
      # @api public
      # @return [#call, nil] the callable, or nil for none
      # @example Total the resources a client reads
      #   client.on_response = ->(response) { total += response.resource_count }
      attr_accessor :on_response

      # The headers sent with every request the client makes
      # @api public
      # @return [Hash{String => String}] the headers, frozen
      # @example Read the headers a client sends
      #   client.headers # => {"User-Agent" => "my-app/1.0"}
      attr_reader :headers

      # Set the base URL for API requests
      #
      # An endpoint is resolved against the base URL, which drops the last segment of a path that does not end with a
      # slash, so a slash is added to a base URL without one.
      #
      # @api public
      # @param base_url [String] the base URL for API requests
      # @return [void]
      # @example Set the base URL
      #   client.base_url = "https://api.x.com/1.1"
      #   client.base_url # => "https://api.x.com/1.1/"
      def base_url=(base_url)
        @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      end

      # Set the headers sent with every request the client makes
      #
      # They are defaults: a header of the same name passed to a request, or to a stream, is sent in place of the
      # client's, and each of them is sent in place of a default of the gem, such as its User-Agent. A header that
      # carries credentials, such as Authorization or Cookie, is dropped by a redirect to another origin, as one
      # passed to a request is.
      #
      # @api public
      # @param headers [Hash{String => String}] the headers, which are copied and frozen
      # @return [void]
      # @example Name the application in the User-Agent of every request
      #   client.headers = {"User-Agent" => "my-app/1.0 (+https://example.com)"}
      def headers=(headers)
        @headers = headers.dup.freeze
      end

      def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :keep_alive_timeout, :proxy_url, :debug_output
      def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :keep_alive_timeout=, :proxy_url=, :debug_output=
      def_delegators :@redirect_handler, :max_redirects, :max_redirects=
      def_delegators :@rate_limit_handler, :max_rate_limit_retries, :max_rate_limit_retries=, :max_rate_limit_wait, :max_rate_limit_wait=

      protected

      # The settings, as initialize accepts them
      # @api private
      # @return [Hash{Symbol => Object}] the settings
      def settings
        {base_url:, open_timeout:, read_timeout:, write_timeout:, keep_alive_timeout:, debug_output:, proxy_url:,
         default_array_class:, default_object_class:, headers:, max_redirects:, max_rate_limit_retries:,
         max_rate_limit_wait:, on_response:, on_token_refresh:}
      end

      private

      # Initialize the settings, and the handlers of redirects and rate limits
      # @api private
      # @param base_url [String] the base URL for API requests
      # @param default_array_class [Class] the default class for parsing JSON arrays
      # @param default_object_class [Class] the default class for parsing JSON objects
      # @param headers [Hash{String => String}] the headers sent with every request
      # @param on_response [#call, nil] the callable passed an X::Response after every request and streamed object
      # @param max_redirects [Integer] the maximum number of redirects to follow
      # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
      # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset
      # @return [void]
      def initialize_settings(base_url:, default_array_class:, default_object_class:, headers:, on_response:,
        max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:)
        self.base_url = base_url
        @default_array_class = default_array_class
        @default_object_class = default_object_class
        self.headers = headers
        @on_response = on_response
        @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
        @rate_limit_handler = RateLimitHandler.new(max_rate_limit_retries:, max_rate_limit_wait:)
      end

      # The headers of a request, the client's under the request's own
      #
      # @api private
      # @param request_headers [Hash{String => String}] the headers passed to the request
      # @return [Hash{String => String}] the headers to send
      def headers_for(request_headers) = headers.merge(request_headers)

      # Pass a response to on_response, if there is one
      # @api private
      # @param http_method [Symbol] the HTTP method of the request
      # @param uri [URI::Generic] the URI of the request
      # @param response [Net::HTTPResponse] the HTTP response
      # @return [void]
      def report(http_method, uri, response)
        on_response&.call(Response.new(http_method, uri, response))
      end
    end
  end
end
