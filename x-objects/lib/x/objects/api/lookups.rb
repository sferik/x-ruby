require_relative "../community"
require_relative "../direct_message"
require_relative "../list"
require_relative "../post"
require_relative "../space"
require_relative "../user"

module X
  module Objects
    module API
      # Lookups, searches, and collections, mixed into a client through API
      # @api public
      module Lookups
        # Look up a user by identifier or username
        #
        # @api public
        # @param id_or_username [Integer, User, String] an identifier or a user, or a username
        # @param params [Hash] query parameters merged over the default parameters
        # @return [User, nil] the user or nil if the user was not found
        # @example Look up a user by username
        #   client.find_user("sferik")
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a user by identifier
        #   client.find_user(7505382)
        def find_user(id_or_username, **params, &)
          User.find(id_or_username, client: self, **params, &)
        end

        # Look up a user by identifier or username, which must exist
        #
        # @api public
        # @param id_or_username [Integer, User, String] an identifier or a user, or a username
        # @param params [Hash] query parameters merged over the default parameters
        # @return [User] the user
        # @raise [ResourceNotFound] if the user was not found
        # @example Look up a user by username
        #   client.find_user!("sferik")
        def find_user!(id_or_username, **params)
          User.find!(id_or_username, client: self, **params)
        end

        # Look up many users by identifier or username, in parallel batches
        #
        # @api public
        # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<User>] the users that were found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up many users by username
        #   client.find_users(["sferik", "gem"])
        def find_users(ids_or_usernames, **params, &)
          User.find_all(ids_or_usernames, client: self, **params, &)
        end

        # The authenticated user, fetched once per client and credentials
        #
        # A client whose credentials change authenticates as someone else, so a client that has an authenticator
        # fetches the user again once the authenticator is replaced.
        #
        # @api public
        # @return [User] the authenticated user
        # @raise [ResourceNotFound] if the API returns no user
        # @example Print the home timeline of the authenticated user
        #   client.current_user.home_timeline.each { |post| puts post.text }
        def current_user
          authenticator = Utils.authenticator_of(self)
          owner, user = @current_user
          return user if user && owner.equal?(authenticator)

          problems = [] #: Array[Problem]
          user = User.current(client: self) { |problem| problems << problem } || raise(ResourceNotFound.new("users/me returned no user", problems:))
          @current_user = [authenticator, user]
          user
        end

        # The identifier of the authenticated user, from an OAuth 1.0a token if possible
        #
        # An OAuth 1.0a access token begins with the identifier of its user, so a client that holds one needs no
        # lookup. Any other client looks the user up once, as current_user does.
        #
        # @api public
        # @return [Integer] the identifier
        # @example Get the identifier of the authenticated user
        #   client.current_user_id # => 7505382
        def current_user_id = Utils.oauth1_user_id(self) || current_user.id

        # Search users
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the matching users
        # @example Print the users matching a query
        #   client.search_users("ruby").each { |user| puts user.username }
        def search_users(query, **params)
          User.search(query, client: self, **params)
        end

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
        # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period
        # @example Count the recent posts about Ruby by hour
        #   client.post_counts("ruby", granularity: "hour")
        def post_counts(query, **params) = Post.counts(query, client: self, **params)

        # Count the posts from the full archive that match a query, by period
        #
        # The API bills a count by the request, not by the post, and refuses OAuth 1.0a for it, so a client that signs
        # with OAuth 1.0a counts with a copy that authenticates as the app.
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters, such as granularity, which is day by default
        # @return [Hash{Time => Integer}] the number of matching posts, keyed by the start of each period
        # @example Count the posts about Ruby by day in 2024
        #   client.all_post_counts("ruby", start_time: "2024-01-01T00:00:00Z", end_time: "2025-01-01T00:00:00Z")
        def all_post_counts(query, **params) = Post.counts_all(query, client: self, **params)

        # Look up how many posts the app's project has read
        #
        # @api public
        # @param params [Hash] query parameters, such as days, the number of days to report, which is 7 by default
        # @return [Usage] the usage
        # @example Check how much of the monthly cap remains
        #   usage = client.usage
        #   usage.project_cap - usage.project_usage
        def usage(**params) = Usage.find(client: self, **params)

        # Look up a list by identifier
        #
        # @api public
        # @param id [String, Integer, List] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [List, nil] the list or nil if the list was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a list
        #   client.find_list(1234567890).name
        def find_list(id, **params, &)
          List.find(id, client: self, **params, &)
        end

        # Look up a list by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, List] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [List] the list
        # @raise [ResourceNotFound] if the list was not found
        # @example Look up a list
        #   client.find_list!(1234567890).name
        def find_list!(id, **params)
          List.find!(id, client: self, **params)
        end

        # Look up a space by identifier
        #
        # @api public
        # @param id [String, Integer, Space] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Space, nil] the space or nil if the space was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a space
        #   client.find_space("1DXxyRYNejbKM").title
        def find_space(id, **params, &)
          Space.find(id, client: self, **params, &)
        end

        # Look up a space by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, Space] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Space] the space
        # @raise [ResourceNotFound] if the space was not found
        # @example Look up a space
        #   client.find_space!("1DXxyRYNejbKM").title
        def find_space!(id, **params)
          Space.find!(id, client: self, **params)
        end

        # Look up many spaces by identifier, in parallel batches
        #
        # @api public
        # @param ids [Array<String, Integer, Space>] the identifiers
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Space>] the spaces that were found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up many spaces
        #   client.find_spaces(["1DXxyRYNejbKM", "1OwGWzarWnNKQ"]).map(&:title)
        def find_spaces(ids, **params, &)
          Space.find_all(ids, client: self, **params, &)
        end

        # Look up a community by identifier
        #
        # @api public
        # @param id [String, Integer, Community] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Community, nil] the community or nil if the community was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a community
        #   client.find_community(1234567890).name
        def find_community(id, **params, &)
          Community.find(id, client: self, **params, &)
        end

        # Look up a community by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, Community] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Community] the community
        # @raise [ResourceNotFound] if the community was not found
        # @example Look up a community
        #   client.find_community!(1234567890).name
        def find_community!(id, **params)
          Community.find!(id, client: self, **params)
        end

        # Search communities
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the matching communities
        # @example Print the communities matching a query
        #   client.search_communities("ruby").each { |community| puts community.name }
        def search_communities(query, **params)
          Community.search(query, client: self, **params)
        end

        # Look up a direct message event by identifier
        #
        # @api public
        # @param id [String, Integer, DirectMessage] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [DirectMessage, nil] the event or nil if the event was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a direct message
        #   client.find_direct_message(1234567890).text
        def find_direct_message(id, **params, &)
          DirectMessage.find(id, client: self, **params, &)
        end

        # Look up a direct message event by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, DirectMessage] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [DirectMessage] the event
        # @raise [ResourceNotFound] if the event was not found
        # @example Look up a direct message
        #   client.find_direct_message!(1234567890).text
        def find_direct_message!(id, **params)
          DirectMessage.find!(id, client: self, **params)
        end

        # The most recent direct message events across every conversation
        #
        # @api public
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the events
        # @example Print the most recent direct messages
        #   client.direct_messages.first(10).each { |message| puts message.text }
        def direct_messages(**params)
          DirectMessage.all(client: self, **params)
        end

        # The direct message events in the one-to-one conversation with a user
        #
        # @api public
        # @param user [User, String, Integer] the other participant or their identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Cursor] a cursor over the events
        # @example Print the conversation with a user
        #   client.direct_messages_with(user).each { |message| puts message.text }
        def direct_messages_with(user, **params)
          DirectMessage.with(user, client: self, **params)
        end

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
        alias_method :count_tweets, :count_posts
        alias_method :count_all_tweets, :count_all_posts
        alias_method :tweet_counts, :post_counts
        alias_method :all_tweet_counts, :all_post_counts
        alias_method :find_dm, :find_direct_message
        alias_method :find_dm!, :find_direct_message!
        alias_method :dms, :direct_messages
        alias_method :dms_with, :direct_messages_with
      end
    end
  end
end
