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
    end
  end
end
