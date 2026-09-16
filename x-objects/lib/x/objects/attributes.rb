require_relative "utils"

module X
  module Objects
    # Class-level macros for declaring resource attributes and references
    # @api private
    module Attributes
      # Converters keyed by attribute type
      CONVERTERS = {
        raw: ->(value) { value },
        boolean: ->(value) { value },
        time: ->(value) { Utils.time(value) },
        integer: ->(value) { Utils.integer(value) },
        integers: ->(value) { value&.map { |id| Utils.integer(id) } }
      }.freeze

      # Define a reader for an attribute
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param type [Symbol] the attribute type: raw, boolean, time, integer, or integers
      # @param key [Array<String>] the key path
      # @return [void]
      def attribute(name, type = :raw, key: [name.to_s])
        attribute_names << name
        path = key_path(key)
        converter = CONVERTERS.fetch(type)
        define_method(name) do
          # @type self: Resource
          converter.call(attrs.dig(*path))
        end
        return unless type.eql?(:boolean)

        define_method(:"#{name}?") do
          # @type self: Resource
          attrs.dig(*path).eql?(true)
        end
      end

      # The names of the attributes declared on this class, which pattern matching reads
      #
      # @api private
      # @return [Array<Symbol>] the attribute names
      # @example Get the attributes of a user
      #   X::User.attribute_names
      def attribute_names
        parent = superclass
        @attribute_names ||= parent.is_a?(Attributes) ? parent.attribute_names.dup : [:id]
      end

      # Define a reader that resolves a referenced resource
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [Array<String>] the key path holding the identifier
      # @return [void]
      def reference(name, klass_name, key:)
        path = key_path(key)
        define_method(name) do
          # @type self: Resource
          resolve(X.const_get(klass_name), attrs.dig(*path))
        end
      end

      # Define a reader that resolves a list of referenced resources
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [Array<String>] the key path holding the identifiers
      # @return [void]
      def references(name, klass_name, key:)
        path = key_path(key)
        define_method(name) do
          # @type self: Resource
          Array(attrs.dig(*path)).map { |id| resolve(X.const_get(klass_name), id) }.freeze
        end
      end

      private

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
