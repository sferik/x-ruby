# frozen_string_literal: true

require_relative "serialization"
require_relative "shape"
require_relative "utils"
require_relative "value_equality"
require_relative "value_marshalling"

module X
  module Objects
    # A topic trending in a place, as the trends of the place report it
    #
    # A trend has no identifier, and the API offers no lookup of one, so trends are read a place at a time, a place
    # named by its Yahoo! Where On Earth identifier (WOEID), such as 1 for the whole world.
    #
    # @api public
    class ::X::Trend
      include Serialization
      include ValueEquality
      include ValueMarshalling

      # Every trend field
      #
      # A minor release may add to it the fields the API adds, so that the trends of a place ask for them too.
      FIELDS = %w[trend_name tweet_count].freeze
      # The most trends the API returns for a place, which it returns 20 of unless asked for more
      MAX_TRENDS = 50
      private_constant :MAX_TRENDS

      # The raw attributes of the trend
      # @api public
      # @return [Hash{String => Object}] the attributes
      # @example Get the raw attributes
      #   trend.attrs # => {"trend_name" => "#ruby", "tweet_count" => 1234}
      attr_reader :attrs

      # The topics trending in a place
      #
      # The endpoint takes app-only authentication, or OAuth 2.0 as a user, so a client that signs with OAuth 1.0a
      # reads the trends with a copy that authenticates as the app.
      #
      # @api public
      # @param woeid [Integer, String] the Yahoo! Where On Earth identifier of the place, such as 1 for the world
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters, such as max_trends, which is 50, the most the API returns, unless given
      # @return [Array<Trend>] the trends, frozen
      # @raise [ArgumentError] if the WOEID is not a number, before a request
      # @raise [InvalidAttribute] if the response holds the trends as something other than a list of objects
      # @example Print the topics trending in the world
      #   X::Trend.at(1, client: client).each { |trend| puts trend.name }
      def self.at(woeid, client:, **params)
        path = "trends/by/woeid/#{woeid_of(woeid)}"
        body = Utils.space_client(client).get(Utils.path(path, {"trend.fields" => FIELDS, "max_trends" => MAX_TRENDS}.merge(params)), **Utils::JSON_CLASSES)
        Shape.objects("#{self}.at", body.to_h["data"]).map { |attrs| new(attrs) }.freeze
      end

      # The WOEID of a place, which must be a number
      #
      # @api private
      # @param woeid [Integer, String] the WOEID
      # @return [String] the WOEID
      # @raise [ArgumentError] if the WOEID is not an Integer or a String of digits
      def self.woeid_of(woeid)
        value = case woeid
        when String, Integer then woeid.to_s
        end
        return value if value&.match?(Utils::NUMERIC_ID)

        raise ArgumentError, "#{woeid.inspect} is not a WOEID: pass an Integer, or a String of digits"
      end
      private_class_method :woeid_of

      # Initialize a trend from the attributes the API reported
      #
      # @api public
      # @param attrs [Hash{String, Symbol => Object}] the attributes
      # @return [Trend] a new trend
      # @raise [ArgumentError] if the attributes are not a Hash
      # @example Build a trend
      #   X::Trend.new({"trend_name" => "#ruby", "tweet_count" => 1234})
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

      # The number of posts about the trend
      #
      # It is read from post_count, or from tweet_count, the name the API gives it before it names tweets posts there,
      # as the post count of a user is.
      #
      # @api public
      # @return [Integer, nil] the number of posts, or nil if the API reported none
      # @raise [InvalidAttribute] if the response holds a number of posts that is not a number
      # @example Get the number of posts
      #   trend.post_count # => 1234
      def post_count = Utils.read("#{self.class}#post_count", attrs["post_count"] || attrs["tweet_count"]) { |value| Shape.integer(value) }

      alias_method :tweet_count, :post_count

      # Deconstruct the trend into what its readers read, so it matches a hash pattern
      #
      # A pattern that asks for every key gets name and post_count, and one can ask for the number of posts as
      # tweet_count too, as it can of a user.
      #
      # @api public
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for every reader
      # @return [Hash{Symbol => Object}] what the readers read
      # @raise [InvalidAttribute] if the pattern asks for a number of posts the response holds as something else
      # @example Keep the topics of more than 10,000 posts
      #   X::Trend.at(1, client: client).select { |trend| trend in {post_count: 10_000..} }
      def deconstruct_keys(keys) = Utils.deconstruct(self, keys, %i[name post_count], %i[tweet_count])
    end
  end
end
