# frozen_string_literal: true

require "forwardable"
require_relative "rate_limit_handler"
require_relative "redirect_handler"
require_relative "response"
require_relative "retry_handler"
require_relative "setting_validator"

module X
  module Core
    # The settings of a client other than its credentials: its base URL, parsing classes, hook, and the settings of
    # its connection and handlers, included into ClientInternals
    #
    # A client is built with the settings it keeps for as long as it lives. {Client#with} derives a client whose
    # settings differ, rather than replacing the ones a client holds, so that a request never runs under a setting
    # another thread is halfway through changing.
    #
    # @api private
    module ClientSettings
      extend Forwardable

      # The base URL for API requests
      #
      # {Client#base_url} returns it.
      #
      # @api private
      # @return [String] the base URL for API requests, which ends with a slash
      attr_reader :base_url

      # The default class for parsing JSON arrays
      #
      # {Client#default_array_class} returns it.
      #
      # @api private
      # @return [Class] the default class for parsing JSON arrays
      attr_reader :default_array_class

      # The default class for parsing JSON objects
      #
      # {Client#default_object_class} returns it.
      #
      # @api private
      # @return [Class, #from_response] the default class for parsing JSON objects
      attr_reader :default_object_class

      # The callable passed an X::Response after each request and streamed object
      #
      # {Client#on_response} returns it.
      #
      # @api private
      # @return [#call, nil] the callable, or nil for none
      attr_reader :on_response

      # The headers sent with every request the client makes
      #
      # {Client#headers} returns it.
      #
      # @api private
      # @return [Hash{String, Symbol => String}] the headers, frozen
      attr_reader :headers

      def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :keep_alive_timeout, :debug_output
      def_delegators :@redirect_handler, :max_redirects
      def_delegators :@rate_limit_handler, :max_rate_limit_retries, :max_rate_limit_wait
      def_delegators :@retry_handler, :max_retries

      # Send a request that is safe to send twice again after a failure
      #
      # It is what Client#with_retries does.
      #
      # @api private
      # @yield sends the request
      # @return [Object] what the block returns
      def with_retries(&) = @retry_handler.handle(idempotent: true, resend_unanswered: true, &)

      private

      # Share the connections kept open by the client this one was copied from
      #
      # They are shared when this client opens its connections as that one does; see Connection#share_pool_of.
      # A copy that differs only in what it sends, such as its headers, base URL, or credentials, would otherwise
      # open connections of its own, with a TCP and TLS handshake for each, and keep them open, idle, until it is
      # collected, so a copy made for each request would leave connections to each host behind it.
      #
      # The internals of the client copied call it on those of the copy with __send__, since it is private.
      #
      # @api private
      # @param connection [Connection] the connection of the client this one was copied from
      # @return [void]
      def share_connection(connection) = @connection.share_pool_of(connection)

      # The settings, as initialize accepts them
      # @api private
      # @return [Hash{Symbol => Object}] the settings
      def settings
        {base_url:, open_timeout:, read_timeout:, write_timeout:, keep_alive_timeout:, debug_output:, proxy_url:,
         default_array_class:, default_object_class:, headers:, max_redirects:, max_rate_limit_retries:,
         max_rate_limit_wait:, max_retries:, on_response:, save_tokens:, load_tokens:}
      end

      # Initialize the settings, and the handlers of redirects, rate limits, and retries
      #
      # An endpoint is resolved against the base URL, which drops the last segment of a path that does not end with a
      # slash, so a slash is added to a base URL without one. The headers are copied and frozen, so that changing the
      # Hash a client was built with never changes what it sends.
      #
      # @api private
      # @param base_url [String] the base URL for API requests
      # @param default_array_class [Class] the default class for parsing JSON arrays
      # @param default_object_class [Class, #from_response] the default class for parsing JSON objects
      # @param headers [Hash{String, Symbol => String}] the headers sent with every request
      # @param on_response [#call, nil] the callable passed an X::Response after every request and streamed object
      # @param max_redirects [Integer] the maximum number of redirects to follow
      # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
      # @param max_rate_limit_wait [Integer, Float] the maximum number of seconds to wait for a rate limit to reset
      # @param max_retries [Integer] the maximum number of times to send an idempotent request again after a failure
      # @return [void]
      # @raise [ArgumentError] if on_response is neither nil nor responds to call
      # @raise [ArgumentError] if default_array_class is not a Class, or default_object_class is neither a Class nor
      #   responds to from_response
      def initialize_settings(base_url:, default_array_class:, default_object_class:, headers:, on_response:,
        max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, max_retries:)
        base_url = SettingValidator.base_url!(base_url)
        @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
        @default_array_class = SettingValidator.array_class!(:default_array_class, default_array_class)
        @default_object_class = SettingValidator.object_class!(:default_object_class, default_object_class)
        @headers = SettingValidator.headers!(headers).transform_keys(&:to_s).freeze
        @on_response = SettingValidator.callable!(:on_response, on_response)
        @redirect_handler = RedirectHandler.new(connection: @connection, request_builder: @request_builder, max_redirects:)
        @rate_limit_handler = RateLimitHandler.new(max_rate_limit_retries:, max_rate_limit_wait:)
        @retry_handler = RetryHandler.new(max_retries:)
      end

      # The headers of a request, the client's under the request's own
      #
      # A header of the request is sent in place of one of the client whose name differs from it in case alone.
      #
      # @api private
      # @param request_headers [Hash{String => String}] the headers passed to the request
      # @return [Hash{String => String}] the headers to send
      def headers_for(request_headers) = RequestBuilder.merge_headers(headers, request_headers)

      # Pass a response to on_response and to the block of the request
      #
      # Both receive the one summary, the client's hook first, so that a hook which counts every request and a block
      # which reads the response of one see the same object. Neither is built a summary when there is nothing to
      # pass it to.
      #
      # @api private
      # @param http_method [Symbol, String] the HTTP method of the request, in any case
      # @param uri [URI::Generic] the URI of the request
      # @param response [Net::HTTPResponse] the HTTP response
      # @yieldparam response [Response] the summary of the response
      # @return [void]
      def report(http_method, uri, response, &block)
        return unless on_response || block

        summary = Response.new(http_response: response, http_method:, uri:)
        on_response&.call(summary)
        block&.call(summary)
      end
    end
    private_constant :ClientSettings
  end
end
