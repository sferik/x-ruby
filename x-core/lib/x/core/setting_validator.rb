# frozen_string_literal: true

require "uri"

module X
  module Core
    # Checks the settings of the handlers of a client when the client is built
    #
    # A setting is compared with a count of attempts or a number of seconds only once a request has failed, so a
    # setting that is not a number, such as a String read from an environment variable, would raise from that
    # comparison, in place of the failure it was compared for. So each is checked when the handler is built, which
    # is when the client that holds it is.
    #
    # A timeout is handed to Net::HTTP, which reads it only once a request waits, so a timeout that is not a number
    # raises from inside Net::HTTP as the first request is sent, and Float::INFINITY raises there too, or ends the
    # thread that Timeout keeps for every timeout of the process, since no deadline can be set that far off. So each
    # is checked when the connection is built, which is when the client that holds it is.
    #
    # The base URL and the headers of a client are read only once a request is built, so a base URL that is no URL,
    # or headers that are not a Hash of names to values, raised from the first request, rather than where the client
    # was given them, so each is checked when the client is built.
    #
    # Internal to x-core: the handlers of redirects, rate limits, retries, and reconnects, a connection, and a client
    # check their settings with it.
    #
    # @api private
    module SettingValidator
      extend self

      # The message of the error raised for a count that is not an Integer of at least 0
      INVALID_COUNT = "%s must be an Integer of at least 0, not %s"
      # The message of the error raised for a count that is neither an Integer of at least 0 nor Float::INFINITY
      INVALID_COUNT_OR_INFINITY = "%s must be an Integer of at least 0, or Float::INFINITY for no limit, not %s"
      # The message of the error raised for seconds that are not a number of at least 0
      INVALID_SECONDS = "%s must be a number of seconds of at least 0, not %s"
      # The message of the error raised for seconds that are not a finite number of at least 0
      INVALID_FINITE_SECONDS = "%s must be a finite number of seconds of at least 0, not %s"
      # The message of the error raised for a timeout that is neither a finite number of seconds of at least 0 nor nil
      INVALID_TIMEOUT = "%s must be a finite number of seconds of at least 0, or nil for no timeout, not %s"
      # The message of the error raised for a base URL that is not an absolute HTTP or HTTPS URL
      INVALID_BASE_URL = "base_url must be an absolute http or https URL, such as \"https://api.x.com/2/\", not %s"
      # The message of the error raised for headers that are not a Hash
      INVALID_HEADERS = "headers must be a Hash of header names to values, not a %s"
      # The message of the error raised for a header whose name or value is not what a header takes
      INVALID_HEADER = "headers must name each header with a String or a Symbol and give it a String, " \
        "not %<name>s with a %<value>s"
      # The message of the error raised for a callable that does not respond to call
      INVALID_CALLABLE = "%s must respond to call, as a Proc or a lambda does, or be nil, not a %s"
      private_constant :INVALID_COUNT, :INVALID_COUNT_OR_INFINITY, :INVALID_SECONDS, :INVALID_FINITE_SECONDS, :INVALID_TIMEOUT,
        :INVALID_BASE_URL, :INVALID_HEADERS, :INVALID_HEADER, :INVALID_CALLABLE

      # Check that a count is an Integer of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer] the value
      # @raise [ArgumentError] if the value is not an Integer of at least 0
      # @example Check the retries of a client
      #   X::Core::SettingValidator.count!(:max_retries, 2) # => 2
      def count!(name, value)
        return value if count?(value)

        raise ArgumentError, format(INVALID_COUNT, name, value.inspect)
      end

      # Check that a count is an Integer of at least 0, or Float::INFINITY for no limit
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is neither an Integer of at least 0 nor Float::INFINITY
      # @example Check the reconnects of a stream
      #   X::Core::SettingValidator.count_or_infinity!(:max_reconnects, Float::INFINITY) # => Infinity
      def count_or_infinity!(name, value)
        return value if count?(value) || Float::INFINITY.eql?(value)

        raise ArgumentError, format(INVALID_COUNT_OR_INFINITY, name, value.inspect)
      end

      # Check that seconds are a real number of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is not a real number of at least 0
      # @example Check the longest wait for a rate limit
      #   X::Core::SettingValidator.seconds!(:max_rate_limit_wait, 900) # => 900
      def seconds!(name, value)
        return value if seconds?(value)

        raise ArgumentError, format(INVALID_SECONDS, name, value.inspect)
      end

      # Check that seconds are a finite real number of at least 0
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is not a finite real number of at least 0
      # @example Check the time a connection is kept open
      #   X::Core::SettingValidator.finite_seconds!(:keep_alive_timeout, 30) # => 30
      def finite_seconds!(name, value)
        return value if finite_seconds?(value)

        raise ArgumentError, format(INVALID_FINITE_SECONDS, name, value.inspect)
      end

      # Check that a timeout is finite seconds of at least 0, or nil for no timeout
      #
      # Net::HTTP waits for as long as it takes when a timeout is nil.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float, nil] the value
      # @raise [ArgumentError] if the value is neither a finite real number of at least 0 nor nil
      # @example Check the timeout for reading a response
      #   X::Core::SettingValidator.timeout!(:read_timeout, 60) # => 60
      def timeout!(name, value)
        return value if value.nil? || finite_seconds?(value)

        raise ArgumentError, format(INVALID_TIMEOUT, name, value.inspect)
      end

      # Check that a base URL is an absolute HTTP or HTTPS URL, with a host
      #
      # @api private
      # @param value [Object] the base URL
      # @return [String] the base URL
      # @raise [ArgumentError] if the base URL is not a String that is an absolute http or https URL with a host
      # @example Check the base URL of the v1.1 API
      #   X::Core::SettingValidator.base_url!("https://api.x.com/1.1/") # => "https://api.x.com/1.1/"
      def base_url!(value)
        return value if value.is_a?(String) && http_url?(value)

        raise ArgumentError, format(INVALID_BASE_URL, value.inspect)
      end

      # Check that headers are a Hash of header names to String values
      #
      # Each header must be named with a String or a Symbol. The error names the class of what is not a Hash, and the
      # name of a header whose name or value is not what a header takes with the class of its value, rather than
      # inspect either, since headers carry credentials, such as an Authorization header.
      #
      # @api private
      # @param value [Object] the headers
      # @return [Hash{String, Symbol => String}] the headers
      # @raise [ArgumentError] if the headers are not a Hash, or name a header with anything but a String or a
      #   Symbol, or give one anything but a String
      # @example Check headers that name the application
      #   X::Core::SettingValidator.headers!("User-Agent" => "MyApp/1.0") # => {"User-Agent" => "MyApp/1.0"}
      def headers!(value)
        raise ArgumentError, format(INVALID_HEADERS, value.class) unless value.is_a?(Hash)

        invalid = value.find { |name, header| !header_name?(name) || !header.is_a?(String) }
        invalid ? invalid_header!(*invalid) : value
      end

      # Check that a callable responds to call, or is nil
      #
      # A callable is called only once what it is called for happens, such as a refresh, so one that does not respond
      # to call would raise NoMethodError from inside a request, long after the client was given it. The error names
      # its class rather than inspect it, since a callable can close over credentials.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the callable, or nil for none
      # @return [#call, nil] the value
      # @raise [ArgumentError] if the value is neither nil nor responds to call
      # @example Check the loader of the tokens a client shares
      #   X::Core::SettingValidator.callable!(:load_tokens, -> { store.load }) # => #<Proc (lambda)>
      def callable!(name, value)
        return value if value.nil? || value.respond_to?(:call)

        raise ArgumentError, format(INVALID_CALLABLE, name, value.class)
      end

      private

      # Raise for a header whose name or value is not what a header takes
      # @api private
      # @param name [Object] the name of the header
      # @param header [Object] the value of the header
      # @return [void]
      # @raise [ArgumentError] always
      def invalid_header!(name, header)
        raise ArgumentError, format(INVALID_HEADER, name: header_name?(name) ? name.inspect : "a #{name.class}", value: header.class)
      end

      # Check whether a value names a header, as a String or a Symbol does
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a String or a Symbol
      def header_name?(value) = value.is_a?(String) || value.instance_of?(Symbol)

      # Check whether a String is an absolute HTTP or HTTPS URL with a host
      # @api private
      # @param value [String] the URL
      # @return [Boolean] true if the URL is an absolute http or https URL with a host
      def http_url?(value)
        uri = URI(value)
        uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
      rescue URI::InvalidURIError
        false
      end

      # Check whether a value is an Integer of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is an Integer of at least 0
      def count?(value) = value.instance_of?(Integer) && !value.negative?

      # Check whether a value is a real number of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a real number of at least 0
      def seconds?(value) = value.is_a?(Numeric) && value.real? && !value.negative?

      # Check whether a value is a finite real number of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is a finite real number of at least 0
      def finite_seconds?(value) = seconds?(value) && value.finite?
    end
  end
end
