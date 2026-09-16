require "forwardable"
require_relative "rate_limit_handler"
require_relative "redirect_handler"
require_relative "response"

module X
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

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects, :max_redirects=
    def_delegators :@rate_limit_handler, :max_rate_limit_retries, :max_rate_limit_retries=, :max_rate_limit_wait, :max_rate_limit_wait=

    private

    # Initialize the settings, and the handlers of redirects and rate limits
    # @api private
    # @param base_url [String] the base URL for API requests
    # @param default_array_class [Class] the default class for parsing JSON arrays
    # @param default_object_class [Class] the default class for parsing JSON objects
    # @param on_response [#call, nil] the callable passed an X::Response after every request and streamed object
    # @param max_redirects [Integer] the maximum number of redirects to follow
    # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
    # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset
    # @return [void]
    def initialize_settings(base_url:, default_array_class:, default_object_class:, on_response:, max_redirects:,
      max_rate_limit_retries:, max_rate_limit_wait:)
      self.base_url = base_url
      @default_array_class = default_array_class
      @default_object_class = default_object_class
      @on_response = on_response
      @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
      @rate_limit_handler = RateLimitHandler.new(max_rate_limit_retries:, max_rate_limit_wait:)
    end

    # Pass a response to on_response, if there is one
    # @api private
    # @param http_method [Symbol] the HTTP method of the request
    # @param uri [URI::Generic] the URI of the request
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [void]
    def report(http_method, uri, response)
      on_response&.call(Response.new(http_method, uri, response))
    end

    # The settings, as initialize accepts them
    # @api private
    # @return [Hash{Symbol => Object}] the settings
    def settings
      {base_url:, open_timeout:, read_timeout:, write_timeout:, debug_output:, proxy_url:, default_array_class:,
       default_object_class:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, on_response:, on_token_refresh:}
    end
  end
end
