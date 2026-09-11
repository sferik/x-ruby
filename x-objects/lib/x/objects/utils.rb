require "time"
require "uri"

module X
  module Objects
    # Helpers shared across the object layer
    # @api private
    module Utils
      # Parsing options that make a client return plain hashes and arrays, whatever its defaults
      JSON_CLASSES = {array_class: Array, object_class: Hash}.freeze

      extend self

      # Return a deep-frozen copy of a value with string keys
      #
      # @api private
      # @param value [Object] the value to copy and freeze
      # @return [Object] the frozen copy
      def deep_freeze(value)
        case value
        when Hash then value.transform_keys(&:to_s).transform_values { |element| deep_freeze(element) }.freeze
        when Array then value.map { |element| deep_freeze(element) }.freeze
        when String then value.dup.freeze
        else value
        end
      end

      # Build an endpoint path with an encoded query string
      #
      # @api private
      # @param base [String] the endpoint path without a query string
      # @param params [Hash] the query parameters
      # @return [String] the endpoint path with a query string
      def path(base, params)
        query = query(params)
        return base if query.empty?

        "#{base}?#{URI.encode_www_form(query)}"
      end

      # Normalize query parameters into string keys and comma-separated values
      #
      # @api private
      # @param params [Hash] the query parameters
      # @return [Hash{String => String, Integer}] the normalized parameters
      def query(params)
        params.transform_keys(&:to_s).compact.transform_values { |value| value.is_a?(Array) ? value.join(",") : value }
      end

      # Merge query parameters over defaults, dropping parameters set to nil
      #
      # @api private
      # @param defaults [Hash] the default query parameters
      # @param params [Hash] the query parameters to merge over the defaults
      # @return [Hash{String => String, Integer}] the normalized parameters
      def merge_params(defaults, params)
        query(defaults.merge(params))
      end

      # Extract an identifier from a resource or a raw value
      #
      # @api private
      # @param value [#id, String, Integer] a resource or an identifier
      # @return [String] the identifier
      def id_of(value)
        value.respond_to?(:id) ? value.id.to_s : value.to_s
      end

      # Check whether a value identifies a resource rather than naming one
      #
      # An Integer is an identifier and a String is a name, such as a username, so that an
      # account whose username is all digits is looked up as the name it is.
      #
      # @api private
      # @param value [#id, String, Integer] a resource, an identifier, or a username
      # @return [Boolean] true if the value is a resource or an Integer identifier
      def id?(value)
        value.respond_to?(:id) || value.instance_of?(Integer)
      end

      # Parse an ISO 8601 timestamp
      #
      # @api private
      # @param value [String, nil] the timestamp
      # @return [Time, nil] the parsed time or nil if the timestamp is missing
      def time(value)
        Time.iso8601(value) unless value.nil?
      end
    end
  end
end
