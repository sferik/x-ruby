require_relative "../../post"
require_relative "../../usage"

module X
  module Objects
    module API
      module Lookups
        # Look up, search, and count posts, and report how many posts the app has read, mixed into a client through API
        # @api public
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
          # @raise [ResourceNotFound] if the post was not found
          # @example Look up a post
          #   client.find_post!(1234567890).text
          def find_post!(id, **params)
            Post.find!(id, client: self, **params)
          end

          # Look up many posts by identifier, in parallel batches
          #
          # @api public
          # @param ids [Array<String, Integer, Post>] the identifiers
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Array<Post>] the posts that were found
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up many posts
          #   client.find_posts([1234567890, 1234567891])
          def find_posts(ids, **params, &)
            Post.find_all(ids, client: self, **params, &)
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
          # @param params [Hash] query parameters, such as start_time and end_time
          # @return [Integer] the number of matching posts
          # @example Count the recent posts about Ruby with an app-only client
          #   client.count_posts("ruby")
          def count_posts(query, **params) = Post.count(query, client: self, **params)

          # Count the posts from the full archive that match a query, without reading them
          #
          # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
          # with OAuth 1.0a counts with a copy that authenticates as the app.
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters, such as start_time and end_time
          # @return [Integer] the number of matching posts
          # @example Count every post about Ruby from 2024
          #   client.count_all_posts("ruby", start_time: "2024-01-01T00:00:00Z", end_time: "2025-01-01T00:00:00Z")
          def count_all_posts(query, **params) = Post.count_all(query, client: self, **params)

          # Count the posts from the last seven days that match a query, by period
          #
          # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
          # with OAuth 1.0a counts with a copy that authenticates as the app.
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters, such as granularity, which is day by default
          # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period, oldest first
          # @example Count the recent posts about Ruby by hour
          #   client.count_posts_by_period("ruby", granularity: "hour")
          def count_posts_by_period(query, **params) = Post.count_by_period(query, client: self, **params)

          # Count the posts from the full archive that match a query, by period
          #
          # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
          # with OAuth 1.0a counts with a copy that authenticates as the app.
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters, such as granularity, which is day by default
          # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period, oldest first
          # @example Count the posts about Ruby by day in 2024
          #   client.count_all_posts_by_period("ruby", start_time: "2024-01-01T00:00:00Z", end_time: "2025-01-01T00:00:00Z")
          def count_all_posts_by_period(query, **params) = Post.count_all_by_period(query, client: self, **params)

          # Look up how many posts the app's project has read
          #
          # @api public
          # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
          # @return [Usage] the usage
          # @example Check how much of the monthly cap remains
          #   usage = client.usage
          #   usage.project_cap - usage.project_usage
          def usage(**params) = Usage.find(client: self, **params)

          # Search recent posts, the short form of search_posts
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Cursor] a cursor over the matching posts
          # @example Print posts about Ruby
          #   client.search("ruby -is:retweet").each { |post| puts post.text }
          def search(query, **params)
            search_posts(query, **params)
          end

          alias_method :find_tweet, :find_post
          alias_method :find_tweet!, :find_post!
          alias_method :find_tweets, :find_posts
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
end
