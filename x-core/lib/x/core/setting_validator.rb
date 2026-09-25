# frozen_string_literal: true

module X
  module Core
    # Checks the settings of the handlers of a client when the client is built
    #
    # A setting is compared with a count of attempts or a number of seconds only once a request has failed, so a
    # setting that is not a number, such as a String read from an environment variable, would raise from that
    # comparison, in place of the failure it was compared for. So each is checked when the handler is built, which
    # is when the client that holds it is.
    #
    # Internal to x-core: the handlers of redirects, rate limits, retries, and reconnects check their settings with
    # it.
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
      private_constant :INVALID_COUNT, :INVALID_COUNT_OR_INFINITY, :INVALID_SECONDS

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
        return value if value.is_a?(Numeric) && value.real? && !value.negative?

        raise ArgumentError, format(INVALID_SECONDS, name, value.inspect)
      end

      private

      # Check whether a value is an Integer of at least 0
      # @api private
      # @param value [Object] the value
      # @return [Boolean] true if the value is an Integer of at least 0
      def count?(value) = value.instance_of?(Integer) && !value.negative?
    end
  end
end
