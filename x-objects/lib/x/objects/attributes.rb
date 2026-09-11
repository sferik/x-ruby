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
        time: ->(value) { Utils.time(value) }
      }.freeze

      # Define a reader for an attribute
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param type [Symbol] the attribute type: raw, boolean, or time
      # @param key [String, Array<String>] the attribute key or nested key path
      # @return [void]
      def attribute(name, type = :raw, key: name.to_s)
        converter = CONVERTERS.fetch(type)
        define_method(name) { converter.call(attrs.dig(*key)) } # steep:ignore
        define_method(:"#{name}?") { attrs.dig(*key).eql?(true) } if type.eql?(:boolean) # steep:ignore
      end

      # Define a reader that resolves a referenced resource
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [String, Array<String>] the attribute key or nested key path holding the identifier
      # @return [void]
      def reference(name, klass_name, key:)
        define_method(name) { resolve(X.const_get(klass_name), attrs.dig(*key)) } # steep:ignore
      end

      # Define a reader that resolves a list of referenced resources
      #
      # @api private
      # @param name [Symbol] the reader name
      # @param klass_name [Symbol] the referenced resource class name under X
      # @param key [String, Array<String>] the attribute key or nested key path holding the identifiers
      # @return [void]
      def references(name, klass_name, key:)
        define_method(name) { Array(attrs.dig(*key)).map { |id| resolve(X.const_get(klass_name), id) }.freeze } # steep:ignore
      end
    end
  end
end
