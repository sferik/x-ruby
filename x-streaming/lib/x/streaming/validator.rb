# frozen_string_literal: true

module X
  module Streaming
    # Checks the settings of a streaming client and the parsing classes of a stream before a stream is opened
    #
    # Internal to x-streaming: StreamingClient and ReconnectHandler check what they are given with it, with the
    # messages X::Client checks its own settings with.
    #
    # @api private
    module Validator
      extend self

      # The message of the error raised for a count that is neither an Integer of at least 0 nor Float::INFINITY
      INVALID_COUNT_OR_INFINITY = "%s must be an Integer of at least 0, or Float::INFINITY for no limit, not %s"
      # The message of the error raised for a read timeout that is neither a finite number of seconds above 0 nor nil
      INVALID_READ_TIMEOUT = "%s must be a finite number of seconds greater than 0, or nil for no timeout, not %s"
      # The message of the error raised for an array_class that is not a Class
      INVALID_ARRAY_CLASS = "%s must be a Class that JSON.parse builds each array into, such as Array, not %s"
      # The message of the error raised for an object_class that is neither a Class nor responds to from_response
      INVALID_OBJECT_CLASS = "%s must be a Class that JSON.parse builds each object into, such as Hash, or respond to " \
        "from_response, as the resource classes of x-objects do, not %s"
      private_constant :INVALID_COUNT_OR_INFINITY, :INVALID_READ_TIMEOUT, :INVALID_ARRAY_CLASS, :INVALID_OBJECT_CLASS

      # Check that a count is an Integer of at least 0, or Float::INFINITY for no limit
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float] the value
      # @raise [ArgumentError] if the value is neither an Integer of at least 0 nor Float::INFINITY
      def count_or_infinity!(name, value)
        return value if (value.instance_of?(Integer) && !value.negative?) || Float::INFINITY.eql?(value)

        raise ArgumentError, format(INVALID_COUNT_OR_INFINITY, name, value.inspect)
      end

      # Check that a read timeout is a finite number of seconds above 0, or nil for none
      #
      # A read timeout of 0 times out each read of a stream at once, so that it reconnects without end, delivering
      # nothing, where the read timeout of a request may be 0; X sends a quiet stream a keep-alive every 20 seconds, so
      # a read timeout shorter than that drops a stream that is quiet but connected.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float, nil] the value
      # @raise [ArgumentError] if the value is neither a finite real number greater than 0 nor nil
      def read_timeout!(name, value)
        return value if value.nil? || (value.is_a?(Numeric) && value.real? && value.positive? && value.finite?)

        raise ArgumentError, format(INVALID_READ_TIMEOUT, name, value.inspect)
      end

      # Check the classes a stream parses its objects into
      #
      # @api private
      # @param array_class [Object] the class for parsing JSON arrays
      # @param object_class [Object] the class for parsing JSON objects, or one that responds to from_response
      # @return [void]
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response
      def parsing_classes!(array_class:, object_class:)
        raise ArgumentError, format(INVALID_ARRAY_CLASS, :array_class, array_class.inspect) unless array_class.instance_of?(Class)
        return if object_class.instance_of?(Class) || object_class.respond_to?(:from_response)

        raise ArgumentError, format(INVALID_OBJECT_CLASS, :object_class, object_class.inspect)
      end
    end
    private_constant :Validator
  end
end
