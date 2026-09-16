require_relative "utils"

module X
  module Objects
    # Counts of the posts that match a query, which the API bills by the request rather than by the post
    #
    # The counts endpoints refuse OAuth 1.0a, so a client that signs with it counts with a copy that authenticates as
    # the app.
    #
    # @api public
    module PostCounts
      # The endpoint that counts the posts from the last seven days
      RECENT_ENDPOINT = "tweets/counts/recent".freeze
      # The endpoint that counts the posts from the full archive
      ALL_ENDPOINT = "tweets/counts/all".freeze
      # The granularity that makes the fewest periods, and so the least data
      DEFAULT_GRANULARITY = "day".freeze

      # Count the recent posts that match a query, without reading them
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as start_time and end_time
      # @return [Integer] the number of matching posts
      # @example Count the recent posts about Ruby
      #   X::Post.count("ruby", client: client)
      def count(query, client:, **params) = total(pages(RECENT_ENDPOINT, query, client:, **params))

      # Count the posts from the full archive that match a query, without reading them
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as start_time and end_time
      # @return [Integer] the number of matching posts
      # @example Count every post about Ruby
      #   X::Post.count_all("ruby", client: client)
      def count_all(query, client:, **params) = total(pages(ALL_ENDPOINT, query, client:, **params))

      # Count the posts from the last seven days that match a query, by period
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as granularity, which is day by default
      # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period
      # @example Count the recent posts about Ruby by hour
      #   X::Post.counts("ruby", client: client, granularity: "hour")
      def counts(query, client:, **params) = periods(pages(RECENT_ENDPOINT, query, client:, **params))

      # Count the posts from the full archive that match a query, by period
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as granularity, which is day by default
      # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period
      # @example Count every post about Ruby by day
      #   X::Post.counts_all("ruby", client: client)
      def counts_all(query, client:, **params) = periods(pages(ALL_ENDPOINT, query, client:, **params))

      private

      # Request every page of counts, following the next page token
      # @api private
      # @param path [String] the counts endpoint path
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters
      # @return [Array<Hash>] the response bodies
      def pages(path, query, client:, **params)
        params = {query:, granularity: DEFAULT_GRANULARITY}.merge(params)
        client = Utils.app_client(client)
        bodies = [] #: Array[Hash[String, untyped]]
        loop do
          bodies << client.get(Utils.path(path, params), **Utils::JSON_CLASSES).to_h
          token = bodies.last.dig("meta", "next_token") or break
          params = params.merge(next_token: token)
        end
        bodies
      end

      # The total count of every page, which the API names for tweets or for posts
      # @api private
      # @param bodies [Array<Hash>] the response bodies
      # @return [Integer] the total
      def total(bodies) = bodies.sum { |body| body.dig("meta", "total_tweet_count") || body.dig("meta", "total_post_count") || 0 }

      # The count of each period of every page, keyed by the start of the period
      # @api private
      # @param bodies [Array<Hash>] the response bodies
      # @return [Hash{Time => Integer}] the counts
      def periods(bodies)
        bodies.flat_map { |body| Array(body["data"]) }.to_h { |period| [Utils.time(period.fetch("start")), period.fetch("tweet_count") { period.fetch("post_count") }] }.freeze
      end
    end
  end
end
