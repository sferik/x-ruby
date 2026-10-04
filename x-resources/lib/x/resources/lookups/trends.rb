# frozen_string_literal: true

require_relative "../personalized_trend"
require_relative "../trend"

module X
  module Resources
    module Lookups
      # Read the topics trending in a place, and for the authenticated user, mixed into a client through API
      #
      # Internal to x-resources: X::Resources::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, so include API rather than this module alone.
      #
      # @api semipublic
      module Trends
        # The topics trending in a place
        #
        # @api public
        # @param woeid [Integer, String] the Yahoo! Where On Earth identifier of the place, such as 1 for the world
        # @param params [Hash] query parameters, such as max_trends, which is 50, the most the API returns, unless given
        # @return [Array<Trend>] the trends, frozen
        # @raise [ArgumentError] if the WOEID is not a number, before a request
        # @example Print the ten topics trending most in the world
        #   client.trends(1, max_trends: 10).each { |trend| puts trend.name }
        def trends(woeid, **params) = Trend.at(woeid, client: self, **params)

        # The topics trending for the authenticated user
        #
        # @api public
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<PersonalizedTrend>] the trends, frozen
        # @example Print the topics trending for the authenticated user
        #   client.personalized_trends.each { |trend| puts trend.name }
        def personalized_trends(**params) = PersonalizedTrend.all(client: self, **params)
      end
    end
  end
end
