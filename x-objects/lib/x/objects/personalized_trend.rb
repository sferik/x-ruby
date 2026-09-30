# frozen_string_literal: true

require_relative "serialization"
require_relative "shape"
require_relative "utils"
require_relative "value_equality"
require_relative "value_marshalling"

module X
  module Objects
    # A topic trending for the authenticated user, as the trends X picks for them report it
    #
    # A personalized trend has no identifier, and the API offers no lookup of one, so the trends are read all at once,
    # for the user the client authenticates as. They are described as they are shown: the number of posts, and how long
    # the topic has trended, are text such as "12.3K posts", rather than numbers.
    #
    # @api public
    class ::X::PersonalizedTrend
      include Serialization
      include ValueEquality
      include ValueMarshalling

      # The endpoint that reports the trends of the authenticated user
      ENDPOINT = "users/personalized_trends"
      private_constant :ENDPOINT
      # Every personalized trend field
      #
      # A minor release may add to it the fields the API adds, so that the trends ask for them too.
      FIELDS = %w[category post_count trend_name trending_since].freeze

      # The raw attributes of the trend
      # @api public
      # @return [Hash{String => Object}] the attributes
      # @example Get the raw attributes
      #   trend.attrs # => {"trend_name" => "#ruby", "category" => "Technology", ...}
      attr_reader :attrs

      # @!method to_h
      #   Alias for attrs, returns the raw attributes
      #   @api public
      #   @return [Hash{String => Object}] the attributes
      #   @example Convert a trend to a hash
      #     trend.to_h
      alias_method :to_h, :attrs

      # The topics trending for the authenticated user
      #
      # The endpoint names no user, so these are always the trends of the user the client authenticates as, and it
      # takes a user's authentication alone, so a client that authenticates as the app is refused.
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<PersonalizedTrend>] the trends, frozen
      # @raise [InvalidAttribute] if the response holds the trends as something other than a list of objects
      # @example Print the topics trending for the authenticated user
      #   X::PersonalizedTrend.all(client: client).each { |trend| puts "#{trend.name}: #{trend.post_count_text}" }
      def self.all(client:, **params)
        body = client.get(Utils.path(ENDPOINT, {"personalized_trend.fields" => FIELDS}.merge(params)), **Utils::JSON_CLASSES)
        Shape.objects("#{self}.all", body.to_h["data"]).map { |attrs| new(attrs) }.freeze
      end

      # Initialize a trend from the attributes the API reported
      #
      # @api public
      # @param attrs [Hash{String => Object}] the attributes
      # @return [PersonalizedTrend] a new trend
      # @raise [ArgumentError] if the attributes are not a Hash
      # @example Build a trend
      #   X::PersonalizedTrend.new({"trend_name" => "#ruby", "post_count" => "12.3K posts"})
      def initialize(attrs)
        @attrs = Utils.deep_freeze(Utils.attributes!(attrs))
        freeze
      end

      # The name of the trend, such as a hashtag or a phrase
      #
      # @api public
      # @return [String, nil] the name
      # @example Get the name
      #   trend.name # => "#ruby"
      def name = attrs["trend_name"]

      # The category of the trend
      #
      # @api public
      # @return [String, nil] the category
      # @example Get the category
      #   trend.category # => "Technology"
      def category = attrs["category"]

      # The number of posts about the trend, as the text X shows it
      #
      # It is named for the text it is, apart from the post_count of X::Trend, which is an Integer, so that code that
      # reads both trends never takes one for the other.
      #
      # @api public
      # @return [String, nil] the number of posts, as text
      # @example Get the number of posts
      #   trend.post_count_text # => "12.3K posts"
      def post_count_text = attrs["post_count"]

      # How long the topic has trended, as the text X shows it
      #
      # @api public
      # @return [String, nil] how long the topic has trended, as text
      # @example Get how long the topic has trended
      #   trend.trending_since # => "Trending now"
      def trending_since = attrs["trending_since"]

      # Deconstruct the trend into what its readers read, so it matches a hash pattern
      #
      # @api public
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for every reader
      # @return [Hash{Symbol => String, nil}] what the readers read
      # @example Keep the topics of the technology category
      #   X::PersonalizedTrend.all(client: client).select { |trend| trend in {category: "Technology"} }
      def deconstruct_keys(keys) = Utils.deconstruct(self, keys, %i[name category post_count_text trending_since])
    end
  end
end
