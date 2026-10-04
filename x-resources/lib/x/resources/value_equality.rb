# frozen_string_literal: true

module X
  module Resources
    # Equality of what an API response held that has no identifier, by its class and attributes
    #
    # A trend or the usage of a project has no identifier to tell it by, and a rule a post matched is told by its tag
    # as well as its identifier, so two are equal when they are of the same class and hold the same attributes, and
    # equal ones share a hash, so that uniq and a Hash key tell them apart. Every attribute counts, so a topic that
    # trends in two places, with a count of posts in each, is two trends that differ; compare their names to find the
    # topics two places share, as trends.map(&:name).intersect?(other_trends.map(&:name)).
    #
    # Internal to x-resources: the methods it gives X::Trend, X::PersonalizedTrend, X::PostUsage, and X::MatchingRule are
    # public API, but the module is only how they are shared, and which classes include it can change within 1.x.
    #
    # @api semipublic
    module ValueEquality
      # Check whether another object holds the same attributes
      #
      # @api public
      # @param other [Object] the other object
      # @return [Boolean] true if the other is of the same class and holds the same attributes
      # @example Check whether the trends of the world changed since they were last read, a count included
      #   X::Trend.at(1, client: client) == trends
      def ==(other) = other.instance_of?(self.class) && attrs.eql?((_ = other).attrs)
      alias_method :eql?, :==

      # The hash of the object, which equal objects share
      #
      # @api public
      # @return [Integer] the hash
      # @example Collect the distinct rules the posts of a stream matched
      #   posts.flat_map(&:matching_rules).uniq
      def hash = [self.class, attrs].hash
    end
    private_constant :ValueEquality
  end
end
