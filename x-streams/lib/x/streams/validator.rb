# frozen_string_literal: true

module X
  module Streams
    # Checks the settings of a streaming client and the parsing classes of a stream before a stream is opened, and the
    # identifiers of rules
    #
    # Internal to x-streams: StreamingClient and ReconnectHandler check what they are given with it, with the
    # messages X::Client checks its own settings with, and StreamRule and StreamRules read identifiers with it, as
    # x-resources reads them.
    #
    # @api private
    module Validator
      extend self

      # The message of the error raised for a count that is neither an Integer of at least 0 nor Float::INFINITY
      INVALID_COUNT_OR_INFINITY = "%s must be an Integer of at least 0, or Float::INFINITY for no limit, not %s"
      # The fewest seconds a stream may wait for a read: the interval of the keep-alive X sends a quiet stream, and five
      # seconds more, so that a keep-alive that arrives a little late does not time the read out
      MINIMUM_READ_TIMEOUT = 25 # seconds
      # The message of the error raised for a read timeout that is neither a finite number of seconds of at least
      # MINIMUM_READ_TIMEOUT nor nil
      INVALID_READ_TIMEOUT = "%s must be a finite number of seconds of at least #{MINIMUM_READ_TIMEOUT}, five more than the " \
        "20-second interval of the keep-alive X sends a quiet stream, or nil for no timeout, not %s"
      # The message of the error raised for an array_class that is not a Class
      INVALID_ARRAY_CLASS = "%s must be a Class that JSON.parse builds each array into, such as Array, not %s"
      # The message of the error raised for an object_class that is neither a Class nor responds to from_response
      INVALID_OBJECT_CLASS = "%s must be a Class that JSON.parse builds each object into, such as Hash, or respond to " \
        "from_response, as the resource classes of x-resources do, not %s"
      # The message of the error raised for a callback that neither responds to call nor is nil
      INVALID_CALLABLE = "%s must respond to call, as a Proc or a lambda does, or be nil, not %s %s"
      # The pattern of the name of a class that an takes the place of a before, as that of an Integer
      VOWEL = /\A[AEIOU]/
      # The pattern of an identifier given as a String: digits alone, with no sign, underscore, or whitespace
      IDENTIFIER = /\A\d+\z/
      # The message of the error raised for an identifier that is neither an Integer that is not negative nor a String
      # of digits, as Integer() words it
      INVALID_IDENTIFIER = "invalid value for Integer(): %s"
      private_constant :MINIMUM_READ_TIMEOUT, :INVALID_COUNT_OR_INFINITY, :INVALID_READ_TIMEOUT, :INVALID_ARRAY_CLASS, :INVALID_OBJECT_CLASS,
        :INVALID_CALLABLE, :VOWEL, :IDENTIFIER, :INVALID_IDENTIFIER

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

      # Check that a read timeout is a finite number of seconds of at least 25, or nil
      #
      # X sends a quiet stream a keep-alive every 20 seconds, so a read timeout no longer than that drops a stream that
      # is quiet but connected whenever a keep-alive arrives a little late, and one shorter drops it every time, and
      # reconnects it without end, delivering nothing, where the read timeout of a request may be as short as 0.
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [Integer, Float, nil] the value
      # @raise [ArgumentError] if the value is neither a finite real number of at least MINIMUM_READ_TIMEOUT nor nil
      def read_timeout!(name, value)
        return value if value.nil? || (value.is_a?(Numeric) && value.real? && value.finite? && value >= MINIMUM_READ_TIMEOUT)

        raise ArgumentError, format(INVALID_READ_TIMEOUT, name, value.inspect)
      end

      # Check that a callback responds to call, or is nil
      #
      # @api private
      # @param name [Symbol] the name of the setting, which the error names
      # @param value [Object] the value of the setting
      # @return [#call, nil] the value
      # @raise [ArgumentError] if the value neither responds to call nor is nil
      def callable!(name, value)
        return value if value.nil? || value.respond_to?(:call)

        raise ArgumentError, format(INVALID_CALLABLE, name, value.class.to_s.match?(VOWEL) ? "an" : "a", value.class)
      end

      # Read the identifier of a rule as an Integer
      #
      # It is read as strictly as x-resources reads an identifier: an Integer that is not negative, or a String of digits
      # alone, as the API sends one, with no sign, underscore, or whitespace, which Integer() would take, so that
      # " 1_0 " is not read as 10, nor "-1" as -1.
      #
      # @api private
      # @param value [Object] the identifier
      # @return [Integer] the identifier
      # @raise [ArgumentError] if the identifier is neither an Integer that is not negative nor a String of digits
      def identifier!(value)
        return value if value.instance_of?(Integer) && !value.negative?
        raise ArgumentError, format(INVALID_IDENTIFIER, value.to_s.inspect) unless value.instance_of?(String) && IDENTIFIER.match?(value)

        Integer(value, 10)
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
