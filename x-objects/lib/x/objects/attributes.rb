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
      private_constant :EMPTY_LIST
      # The values a flag is read from, which the API gives as true or false, and a response that omits it as nil
      FLAGS = [true, false, nil].freeze
      private_constant :FLAGS
      # Converters keyed by attribute type
      CONVERTERS = {
        raw: ->(value) { value },
        media_key: ->(value) { value },
        boolean: ->(value) { FLAGS.include?(value) ? value : raise(ArgumentError, "#{value.inspect} is not true or false") },
        time: ->(value) { Utils.time(value) },
        integer: ->(value) { Shape.integer(value) },
        integers: ->(value) { (Shape.list(value) || EMPTY_LIST).map { |id| Shape.integer(id) }.freeze },
        list: ->(value) { Shape.list(value) || EMPTY_LIST },
        range: ->(value) { Shape.range(value) },
        requested_list: ->(value) { Shape.list(value) }
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

      # The key paths of the identifiers of the resources this class refers to
      #
      # The problems of a resource are read by them. A key path holds an identifier, a list of them, or a list of objects that each hold one as id, as the
      # referenced_posts of a post do.
      #
      # @api private
      # @return [Array<Array<String>>] the key paths
      # @example Get the key paths of the references of a list
      #   X::List.__send__(:reference_keys) # => [["owner_id"]]
      def reference_keys
        parent = superclass
        @reference_keys ||= parent.respond_to?(:reference_keys, true) ? parent.__send__(:reference_keys).dup : []
      end

      # The identifiers of the resources that attributes of this class refer to
      #
      # A problem is read to tell which resource it is about, so a key path the attributes hold something other than
      # an object along reads as no identifier, rather than raise as the reader of the reference does.
      #
      # @api private
      # @param attrs [Hash{String => Object}] the attributes
      # @return [Array<Object>] the identifiers, as the attributes hold them
      # @example Get the identifiers a post refers to
      #   X::Post.__send__(:referenced_ids, {"id" => "1", "author_id" => "2"}) # => ["2"]
      def referenced_ids(attrs) = reference_keys.flat_map { |path| ids_at(attrs, path) }

      private :attribute_names, :attribute_aliases, :reference_keys, :referenced_ids

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
      # @param type [Symbol] the attribute type: raw, boolean, time, integer, integers, list, or requested_list, of
      #   which integers and list read a list the response omitted as empty, and requested_list, the type of a field no
      #   lookup asks for unless it is requested, reads it as nil, since a response that omits it does not say the list
      #   is empty
      # @param key [Array<String>] the key path
      # @param tweet_key [Array<String>, nil] the key path of the name the API gave the attribute before it named
      #   tweets posts, which it still gives it where it has not renamed it, such as in a stream, read when the
      #   response holds nothing at the key path
      # @return [void]
      # @raise [InvalidAttribute] from the reader, if the response holds a value the type cannot be read from
      def attribute(name, type = :raw, key: [name.to_s], tweet_key: nil)
        attribute_names << name
        paths = key_paths(key, tweet_key)
        converter = CONVERTERS.fetch(type)
        define_method(name) do
          # @type self: Resource
          Utils.read("#{self.class}##{name}", Shape.dig_first("#{self.class}##{name}", attrs, paths)) { |value| converter.call(value) }
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
      # @param tweet_key [Array<String>, nil] the key path of the name the API gave it before it named tweets posts,
      #   read when the response holds nothing at the key path
      # @return [void]
      # @raise [InvalidAttribute] from the reader, if the response holds an identifier that is not one, or a key path
      #   that passes through something other than an object
      def reference(name, klass_name, key:, tweet_key: nil)
        paths = key_paths(key, tweet_key)
        reference_keys.concat(paths)
        define_method(name) do
          # @type self: Resource
          resolve(X.const_get(klass_name), Shape.dig_first("#{self.class}##{name}", attrs, paths))
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
        reference_keys << path
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

      # The key paths an attribute is read at, in the order they are tried
      #
      # @api private
      # @param key [Object] the key path
      # @param tweet_key [Object, nil] the key path of the name the API gave it before it named tweets posts, if any
      # @return [Array<Array<String>>] the key paths
      # @raise [ArgumentError] if a key path is not an array
      def key_paths(key, tweet_key) = [key, tweet_key].compact.each { |path| key_path(path) }

      # The identifiers at a key path
      #
      # A key path holds an identifier, a list of them, or a list of objects that each hold one as id.
      #
      # @api private
      # @param attrs [Hash{String => Object}] the attributes
      # @param path [Array<String>] the key path
      # @return [Array<Object>] the identifiers, with nil for a path that holds none
      def ids_at(attrs, path)
        found = path.reduce(attrs) { |value, key| Hash.try_convert(value)&.[](key) }
        (Array.try_convert(found) || [found]).map { |element| Hash.try_convert(element)&.[]("id") || element }
      end
    end
    private_constant :Attributes
  end
end
