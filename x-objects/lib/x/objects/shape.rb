# frozen_string_literal: true

require_relative "utils"

module X
  module Objects
    # Reads the objects and lists of a response, which must be what the API documents them to be
    #
    # A value the object layer reads into, such as the public_metrics a count is read from, or the links of a post, is
    # checked to be an object or a list before it is read, so that one that is not raises InvalidAttribute, as any
    # value of a response that cannot be read does, rather than the NoMethodError or TypeError of reading into it.
    #
    # @api private
    module Shape
      extend self

      # Read the value at a path of keys, through the object each key but the last names
      #
      # A key that names nothing reads as nil, as Hash#dig does, but one that names something other than an object,
      # such as a String where the API documents public_metrics, cannot be read further.
      #
      # @api private
      # @param name [String] what the value is, such as the reader that reads it
      # @param value [Hash, nil] the object the path starts at
      # @param path [Array<String>] the keys
      # @return [Object, nil] the value, or nil if a key names nothing
      # @raise [InvalidAttribute] if the path passes through something other than an object
      # @example Read the number of times a post was liked
      #   X::Objects::Shape.dig("X::Post#like_count", attrs, %w[public_metrics like_count])
      def dig(name, value, path) = path.reduce(value) { |current, key| read_object(name, current)&.[](key) }

      # Read the value at the first of several paths of keys that names one
      #
      # @api private
      # @param name [String] what the value is, such as the reader that reads it
      # @param value [Hash, nil] the object the paths start at
      # @param paths [Array<Array<String>>] the paths, in the order they are tried
      # @return [Object, nil] the value, or nil if no path names one
      # @raise [InvalidAttribute] if a path passes through something other than an object
      # @example Read the number of times a post was reposted, by either name
      #   X::Objects::Shape.dig_first("X::Post#repost_count", attrs, [%w[public_metrics repost_count], %w[public_metrics retweet_count]])
      def dig_first(name, value, paths)
        paths.each do |path|
          found = dig(name, value, path)
          return found unless found.nil?
        end
        nil
      end

      # Read an object, which the response may leave out
      #
      # @api private
      # @param name [String] what the value is, such as the reader that reads it
      # @param value [Hash, nil] the object
      # @return [Hash, nil] the object, or nil if the value is missing
      # @raise [InvalidAttribute] if the value is not an object
      # @example Read the entities of a post
      #   X::Objects::Shape.read_object("X::Post#entities", attrs["entities"])
      def read_object(name, value) = Utils.read(name, value) { object(value) }

      # Read a list of objects, which the response may leave out
      #
      # @api private
      # @param name [String] what the value is, such as the reader that reads it
      # @param value [Array<Hash>, nil] the list
      # @return [Array<Hash>] the objects, empty if the list is missing
      # @raise [InvalidAttribute] if the value is not a list, or holds something other than an object
      # @example Read the links of a post
      #   X::Objects::Shape.objects("X::Post#urls", entities["urls"])
      def objects(name, value) = Utils.read(name, value) { Array(list(value)).each { |element| object!(element) }.freeze }

      # Check that a value the API documents as an object is one, if it is there
      #
      # @api private
      # @param value [Hash, nil] the value
      # @return [Hash, nil] the object, or nil if the value is missing
      # @raise [ArgumentError] if the value is not an object
      def object(value) = (object!(value) unless value.nil?)

      # Check that a value the API documents as an object is one
      #
      # @api private
      # @param value [Hash] the value
      # @return [Hash] the object
      # @raise [ArgumentError] if the value is not an object
      def object!(value) = Hash.try_convert(value) || raise(ArgumentError, "#{value.inspect} is not an object")

      # Check that a value the API documents as a list is one, if it is there
      #
      # @api private
      # @param value [Array, nil] the value
      # @return [Array, nil] the list, or nil if the value is missing
      # @raise [ArgumentError] if the value is not a list
      def list(value) = (Array.try_convert(value) || raise(ArgumentError, "#{value.inspect} is not a list") unless value.nil?)

      # Read a numeric identifier or a count as an Integer, if it is there
      #
      # It is read as strictly as an identifier is checked: an Integer that is not negative, or a String of digits
      # alone, with no sign, underscore, or whitespace, so that a count reads as the whole number it is, and the
      # identifier of a resource a reader such as author_id returns is one that resource is found by.
      #
      # @api private
      # @param value [String, Integer, nil] the identifier or count
      # @return [Integer, nil] the Integer, or nil if the value is missing
      # @raise [ArgumentError] if the value is neither an Integer that is not negative nor a String of digits
      def integer(value)
        return value if value.nil? || (Integer === value && !value.negative?)
        raise ArgumentError, "invalid value for Integer(): #{value.to_s.inspect}" unless String === value && Utils::NUMERIC_ID.match?(value)

        Integer(value, 10)
      end
    end
    private_constant :Shape
  end
end
