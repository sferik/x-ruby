# frozen_string_literal: true

module X
  module Objects
    # Equality of what an API response held that has no identifier, by its class and attributes
    #
    # A trend or the usage of a project has no identifier to tell it by, and a rule a post matched is told by its tag
    # as well as its identifier, so two are equal when they are of the same class and hold the same attributes, and
    # equal ones share a hash, so that uniq and a Hash key tell them apart.
    #
    # Internal to x-objects: the methods it gives X::Trend, X::PersonalizedTrend, X::Usage, and X::MatchingRule are
    # public API, but the module is only how they are shared, and which classes include it can change within 1.x.
    #
    # @api private
    module ValueEquality
      # Check whether another object holds the same attributes
      #
      # @api public
      # @param other [Object] the other object
      # @return [Boolean] true if the other is of the same class and holds the same attributes
      # @example Check whether a topic trends in two places
      #   X::Trend.at(1, client: client).intersect?(X::Trend.at(23424977, client: client))
      def ==(other) = other.instance_of?(self.class) && attrs.eql?((_ = other).attrs)
      alias_method :eql?, :==

      # The hash of the object, which equal objects share
      #
      # @api public
      # @return [Integer] the hash
      # @example Count the distinct topics trending in some places
      #   woeids.flat_map { |woeid| X::Trend.at(woeid, client: client) }.uniq.size
      def hash = [self.class, attrs].hash
    end
    private_constant :ValueEquality
  end
end
