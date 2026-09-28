# frozen_string_literal: true

require "time"
require_relative "errors"
require_relative "utils"

module X
  module Objects
    # Counts of the posts that match a query, which the API bills by the request rather than by the post
    #
    # The counts endpoints refuse OAuth 1.0a, so a client that signs with it counts with a copy that authenticates as
    # the app.
    #
    # Internal to x-objects: the methods it gives Post, such as X::Post.count, are public API, but the module is only
    # how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module PostCounts
      # The endpoint that counts the posts from the last seven days
      RECENT_ENDPOINT = "tweets/counts/recent"
      # The endpoint that counts the posts from the full archive
      ALL_ENDPOINT = "tweets/counts/all"
      # The granularity that makes the fewest periods, and so the least data
      DEFAULT_GRANULARITY = "day"

      # Count the recent posts that match a query, without reading them
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as start_time and end_time
      # @return [Integer] the number of matching posts
      # @raise [InvalidAttribute] if the response holds a total that is not a number
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
      # @raise [InvalidAttribute] if the response holds a total that is not a number
      # @example Count every post about Ruby
      #   X::Post.count_all("ruby", client: client)
      def count_all(query, client:, **params) = total(pages(ALL_ENDPOINT, query, client:, **params))

      # Count the posts from the last seven days that match a query, by period
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as granularity, which is day by default
      # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period, oldest first
      # @raise [InvalidAttribute] if the response holds a period without a start in ISO 8601, or without a count
      # @example Count the recent posts about Ruby by hour
      #   X::Post.count_by_period("ruby", client: client, granularity: "hour")
      def count_by_period(query, client:, **params) = periods(pages(RECENT_ENDPOINT, query, client:, **params))

      # Count the posts from the full archive that match a query, by period
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters, such as granularity, which is day by default
      # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period, oldest first
      # @raise [InvalidAttribute] if the response holds a period without a start in ISO 8601, or without a count
      # @example Count every post about Ruby by day
      #   X::Post.count_all_by_period("ruby", client: client)
      def count_all_by_period(query, client:, **params) = periods(pages(ALL_ENDPOINT, query, client:, **params))

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
      # @raise [InvalidAttribute] if a page holds a total that is not a number
      def total(bodies) = bodies.sum { |body| page_total(body.dig("meta", "total_tweet_count") || body.dig("meta", "total_post_count")) }

      # The total count of one page, which is zero when the page holds none
      # @api private
      # @param value [Integer, String, nil] the total the page holds
      # @return [Integer] the total
      # @raise [InvalidAttribute] if the total is not a number
      def page_total(value) = Utils.read("The total of the counts of #{self}", value) { Utils.integer(value) } || 0

      # The count of each period of every page, oldest first
      #
      # The API serves the newest page first while each page runs oldest to newest, so the periods of a paginated
      # count are sorted before they are frozen, and the result reads in time order however many pages it took.
      #
      # @api private
      # @param bodies [Array<Hash>] the response bodies
      # @return [Hash{Time => Integer}] the counts, keyed by the start of each period, in time order
      # @raise [InvalidAttribute] if a period has no start in ISO 8601, or no count that is a number
      def periods(bodies)
        entries = bodies.flat_map { |body| Array(body["data"]) } #: Array[Hash[String, untyped]]
        entries.to_h { |entry| period(entry) }.sort.to_h.freeze
      end

      # The start of a period and the number of posts in it
      #
      # The API names the number for tweets or for posts.
      #
      # @api private
      # @param entry [Hash] the period, with its start and its count
      # @return [Array(Time, Integer)] the start and the count
      # @raise [InvalidAttribute] if the period has no start in ISO 8601, or no count that is a number
      def period(entry)
        Utils.read("A period of the counts of #{self}", entry) do
          [Time.iso8601(entry["start"].to_s), Integer((entry["tweet_count"] || entry["post_count"]).to_s, 10)]
        end
      end
    end
  end
end
