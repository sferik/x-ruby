# frozen_string_literal: true

require_relative "shape"
require_relative "utils"

module X
  module Objects
    # Class-level macros for declaring resource attributes and references
    # @api private
    module Attributes
      # The value of a list the response omitted, which reads as empty, as a list of references does, rather than nil
      EMPTY_LIST = [] #: Array[untyped]
      EMPTY_LIST.freeze
      # Converters keyed by attribute type
      CONVERTERS = {
        raw: ->(value) { value },
        boolean: ->(value) { value },
        time: ->(value) { Utils.time(value) },
        integer: ->(value) { Utils.integer(value) },
        integers: ->(value) { (Shape.list(value) || EMPTY_LIST).map { |id| Utils.integer(id) }.freeze },
        list: ->(value) { Shape.list(value) || EMPTY_LIST }
      }.freeze

      # The names of the attributes declared on this class, which pattern matching reads
      #
      # @api private
      # @return [Array<Symbol>] the attribute names
      # @example Get the attributes of a user
      #   X::User.__send__(:attribute_names)
      def attribute_names
        parent = superclass
        @attribute_names ||= parent.respond_to?(:attribute_names, true) ? parent.__send__(:attribute_names).dup : [:id]
      end

      # The other names some attributes are read by, which a pattern can ask for
      #
      # @api private
      # @return [Array<Symbol>] the alias names
      # @example Get the attribute aliases of a user
      #   X::User.__send__(:attribute_aliases) # => [:tweet_count, :pinned_tweet_id, :most_recent_tweet_id]
      def attribute_aliases
        parent = superclass
        @attribute_aliases ||= parent.respond_to?(:attribute_aliases, true) ? parent.__send__(:attribute_aliases).dup : []
      end

      private :attribute_names, :attribute_aliases

      private

      # Define another name for an attribute, which a pattern can ask for
      #
      # @api private
      # @param name [Symbol] the alias name
      # @param original [Symbol] the name of the attribute
      # @return [void]
      def attribute_alias(name, original)
        attribute_aliases << name
        alias_method name, original
      end

      # Define a reader for an attribute
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param type [Symbol] the attribute type: raw, boolean, time, integer, integers, or list, of which integers and
      #   list read a list the response omitted as empty
      # @param key [Array<String>] the key path
      # @return [void]
      # @raise [InvalidAttribute] from the reader, if the response holds a value the type cannot be read from
      def attribute(name, type = :raw, key: [name.to_s])
        attribute_names << name
        path = key_path(key)
        converter = CONVERTERS.fetch(type)
        define_method(name) do
          # @type self: Resource
          Utils.read("#{self.class}##{name}", Shape.dig("#{self.class}##{name}", attrs, path)) { |value| converter.call(value) }
        end
        return unless type.eql?(:boolean)

        define_method(:"#{name}?") do
          # @type self: Resource
          public_send(name).eql?(true)
        end
      end

      # Define a reader that resolves a referenced resource
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [Array<String>] the key path holding the identifier
      # @return [void]
      # @raise [InvalidAttribute] from the reader, if the response holds an identifier that is not one, or a key path
      #   that passes through something other than an object
      def reference(name, klass_name, key:)
        path = key_path(key)
        define_method(name) do
          # @type self: Resource
          resolve(X.const_get(klass_name), Shape.dig("#{self.class}##{name}", attrs, path))
        end
      end

      # Define a reader that resolves a list of referenced resources
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [Array<String>] the key path holding the identifiers
      # @return [void]
      # @raise [InvalidAttribute] from the reader, if the response holds something other than a list of identifiers
      def references(name, klass_name, key:)
        path = key_path(key)
        define_method(name) do
          # @type self: Resource
          reader = "#{self.class}##{name}"
          ids = Utils.read(reader, Shape.dig(reader, attrs, path)) { |value| Shape.list(value) } || EMPTY_LIST
          ids.map { |id| resolve(X.const_get(klass_name), id) }.freeze
        end
      end

      # Check that a key path is an array of keys
      #
      # @api private
      # @param key [Object] the key path to check
      # @return [Array<String>] the key path
      # @raise [ArgumentError] if the key path is not an array
      def key_path(key)
        raise ArgumentError, "key must be an Array of keys, not #{key.inspect}" unless key.is_a?(Array)

        key
      end
    end
  end
end
