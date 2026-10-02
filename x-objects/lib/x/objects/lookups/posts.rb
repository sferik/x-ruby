# frozen_string_literal: true

require_relative "../post"
require_relative "../post_usage"

module X
  module Objects
    module Lookups
      # Look up, search, and count posts, and report how many posts the app has read, mixed into a client through API
      #
      # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api semipublic
      module Posts
        # Look up a post by identifier
        #
        # @api public
        # @param id [String, Integer, Post] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Post, nil] the post or nil if the post was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a post
        #   client.find_post(1234567890).text
        def find_post(id, **params, &)
          Post.find(id, client: self, **params, &)
        end

        # Look up a post by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, Post] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Post] the post
        # @raise [MissingResource] if the post was not found
        # @example Look up a post
        #   client.find_post!(1234567890).text
        def find_post!(id, **params)
          Post.find!(id, client: self, **params)
        end

        # Look up many posts by identifier, in parallel batches
        #
        # @api public
        # @param ids [Array<String, Integer, Post>] the identifiers
        # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; each is
        #   a request of up to 100 posts, so a lower number spends a rate limit more slowly
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Post>] the posts that were found
        # @raise [ArgumentError] if the concurrency is less than one
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up many posts
        #   client.find_all_posts([1234567890, 1234567891])
        # @example Look up many posts one batch at a time
        #   client.find_all_posts(ids, concurrency: 1)
        def find_all_posts(ids, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
          Post.find_all(ids, client: self, concurrency:, **params, &)
        end

        # Search recent posts
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the matching posts
        # @example Print posts about Ruby
        #   client.search_posts("ruby -is:retweet").each { |post| puts post.text }
        def search_posts(query, **params)
          Post.search(query, client: self, **params)
        end

        # The posts of the authenticated user that other users have reposted
        #
        # @api public
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the reposted posts
        # @example Print the reposted posts
        #   client.reposts_of_me.each { |post| puts post.text }
        def reposts_of_me(**params)
          Post.reposts_of_me(client: self, **params)
        end

        # Search the full archive of posts
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the matching posts
        # @example Print every post about Ruby
        #   client.search_all_posts("ruby -is:retweet").each { |post| puts post.text }
        def search_all_posts(query, **params)
          Post.search_all(query, client: self, **params)
        end

        # Count the recent posts that match a query, without reading them
        #
        # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
        # with OAuth 1.0a counts with a copy that authenticates as the app.
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters, such as start_time and end_time, and max_pages, the most pages of
        #   counts to request
        # @return [Integer] the number of matching posts
        # @example Count the recent posts about Ruby with an app-only client
        #   client.count_posts("ruby")
        def count_posts(query, **params) = Post.count(query, client: self, **params) # steep:ignore DifferentMethodParameterKind

        # Count the posts from the full archive that match a query, without reading them
        #
        # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
        # with OAuth 1.0a counts with a copy that authenticates as the app. A client signed in with OAuth 2.0 as a user
        # that holds no credentials of the app counts as the user, which the full archive refuses with X::Forbidden.
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters, such as start_time and end_time, and the max_pages of
        #   X::Post.count_all, which limits the pages of counts requested
        # @return [Integer] the number of matching posts
        # @example Count every post about Ruby from 2024
        #   client.count_all_posts("ruby", start_time: "2024-01-01T00:00:00Z", end_time: "2025-01-01T00:00:00Z")
        def count_all_posts(query, **params) = Post.count_all(query, client: self, **params) # steep:ignore DifferentMethodParameterKind

        # Count the posts from the last seven days that match a query, by period
        #
        # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
        # with OAuth 1.0a counts with a copy that authenticates as the app.
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters, such as granularity, which is day by default, and max_pages, the most
        #   pages of counts to request
        # @return [Hash{Range<Time> => Integer}] the number of matching posts, keyed by the time each period spans,
        #   from its start up to, but not including, its end, oldest first
        # @example Count the recent posts about Ruby by hour
        #   client.count_posts_by_period("ruby", granularity: "hour")
        def count_posts_by_period(query, **params) = Post.count_by_period(query, client: self, **params) # steep:ignore DifferentMethodParameterKind

        # Count the posts from the full archive that match a query, by period
        #
        # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
        # with OAuth 1.0a counts with a copy that authenticates as the app. A client signed in with OAuth 2.0 as a user
        # that holds no credentials of the app counts as the user, which the full archive refuses with X::Forbidden.
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters, such as granularity, which is day by default, and the max_pages of
        #   X::Post.count_all_by_period, which limits the pages of counts requested
        # @return [Hash{Range<Time> => Integer}] the number of matching posts, keyed by the time each period spans,
        #   from its start up to, but not including, its end, oldest first
        # @example Count the posts about Ruby by day in 2024
        #   client.count_all_posts_by_period("ruby", start_time: "2024-01-01T00:00:00Z", end_time: "2025-01-01T00:00:00Z")
        def count_all_posts_by_period(query, **params) = Post.count_all_by_period(query, client: self, **params) # steep:ignore DifferentMethodParameterKind

        # Look up how many posts the app's project has read
        #
        # The usage endpoint takes app-only authentication alone, so a client that signs with OAuth 1.0a looks it up
        # with a copy that authenticates as the app, and one signed in with OAuth 2.0 as a user that holds no
        # credentials of the app is refused with X::Forbidden.
        #
        # A response that holds no usage returns nil, as current_user does for a users/me that holds no user, and
        # passes the problems it reported to the block, if there is one.
        #
        # @api public
        # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
        # @return [PostUsage, nil] the usage, or nil if the response holds none
        # @yieldparam problem [Problem] each problem the API reported
        # @example Check how much of the monthly cap remains
        #   usage = client.post_usage
        #   usage.project_cap - usage.project_usage if usage
        def post_usage(**params, &) = PostUsage.current(client: self, **params, &)

        # Look up how many posts the app's project has read, which must be returned
        #
        # @api public
        # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
        # @return [PostUsage] the usage
        # @raise [MissingResource] if the API returns no usage
        # @example Check how much of the monthly cap remains
        #   usage = client.post_usage!
        #   usage.project_cap - usage.project_usage
        def post_usage!(**params) = PostUsage.current!(client: self, **params)

        alias_method :find_tweet, :find_post
        alias_method :find_tweet!, :find_post!
        alias_method :find_all_tweets, :find_all_posts
        alias_method :search_tweets, :search_posts
        alias_method :search_all_tweets, :search_all_posts
        alias_method :retweets_of_me, :reposts_of_me
        alias_method :count_tweets, :count_posts
        alias_method :count_all_tweets, :count_all_posts
        alias_method :count_tweets_by_period, :count_posts_by_period
        alias_method :count_all_tweets_by_period, :count_all_posts_by_period
      end
    end
  end
end
