# frozen_string_literal: true

require_relative "errors"

module X
  module Objects
    # The state Marshal writes and reads of what an API response held that is not a resource
    #
    # A trend, the usage of a project, and a rule a post matched hold their attributes alone, so what is written is
    # those attributes, led by the number of their format, as a resource is written, and what is read is built of
    # them as the constructor builds it, frozen.
    #
    # Internal to x-objects: the methods it gives X::Trend, X::PersonalizedTrend, X::PostUsage, and X::MatchingRule,
    # marshal_dump, marshal_load, encode_with, and init_with, are public API, but the module is only how they are shared,
    # and which classes include it can change within 1.x.
    #
    # @api private
    module ValueMarshalling
      # The number of the format of the state Marshal writes, which every release of 1.x writes
      #
      # A later release of 1.x adds to the state only what an earlier one ignores, parts after those it reads and keys of a
      # Hash it does not read, so that the state one release of 1.x writes is read by every other, earlier or later.
      MARSHAL_FORMAT = 1
      # The name YAML writes each part of the state under, in the order Marshal writes them
      YAML_KEYS = %w[format attrs].freeze
      private_constant :MARSHAL_FORMAT, :YAML_KEYS

      # The state Marshal writes
      #
      # What is written is plain data, led by the number of its format, so that a value written by one release of 1.x
      # is read by a later one: its attributes, as the API sent them.
      #
      # @api public
      # @return [Array(Integer, Hash{String => Object})] the number of the format, then the attributes
      # @example Cache the trends of a place
      #   Rails.cache.write("trends", X::Trend.at(1, client: client))
      def marshal_dump = [MARSHAL_FORMAT, attrs]

      # Restore a value Marshal read, frozen as the value that was written was
      #
      # @api public
      # @param state [Array] the state Marshal wrote
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read cached trends
      #   Marshal.load(Marshal.dump(trend)).name
      def marshal_load(state)
        format, attrs = state
        raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

        restore(attrs)
      end

      # Write the state Marshal writes as YAML
      #
      # YAML would write the instance variables of the value, and read them back into one that is not frozen, so it says
      # how it is written: each part of the state Marshal writes, under its name.
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML writes the value with
      # @return [void]
      # @example Write a value as YAML
      #   YAML.dump(trend)
      def encode_with(coder) = YAML_KEYS.zip(marshal_dump) { |key, value| coder[key] = value }

      # Restore a value YAML read, frozen, as Marshal restores one
      #
      # @api public
      # @param coder [Psych::Coder] the coder YAML read the value with
      # @return [void]
      # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
      # @example Read a value written as YAML
      #   YAML.unsafe_load(YAML.dump(trend)).name
      def init_with(coder) = marshal_load(coder.map.values_at(*YAML_KEYS))

      private

      # Build the value of the attributes Marshal read, as its constructor builds it
      # @api private
      # @param attrs [Hash{String => Object}] the attributes
      # @return [void]
      def restore(attrs) = initialize(attrs) # steep:ignore UnexpectedPositionalArgument
    end
    private_constant :ValueMarshalling
  end
end
