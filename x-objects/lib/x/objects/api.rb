require_relative "direct_message"
require_relative "list"
require_relative "post"
require_relative "space"
require_relative "user"

module X
  module Objects
    # Resource methods mixed into a client that responds to get, post, and delete
    # @api public
    module API
      # Look up a user by identifier or username
      #
      # @api public
      # @param id_or_username [Integer, User, String] an identifier or a user, or a username
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the user or nil if the user was not found
      # @example Look up a user by username
      #   client.find_user("sferik")
      # @example Look up a user by identifier
      #   client.find_user(7505382)
      def find_user(id_or_username, **params)
        User.find(id_or_username, client: self, **params)
      end

      # Look up many users by identifier or username, in parallel batches
      #
      # @api public
      # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found
      # @example Look up many users by username
      #   client.find_users(["sferik", "gem"])
      def find_users(ids_or_usernames, **params)
        User.find_all(ids_or_usernames, client: self, **params)
      end

      # Look up the authenticated user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the authenticated user
      # @example Look up the authenticated user
      #   client.me.username
      def me(**params)
        User.me(client: self, **params)
      end

      # Look up a post by identifier
      #
      # @api public
      # @param id [String, Integer, Post] the identifier
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Post, nil] the post or nil if the post was not found
      # @example Look up a post
      #   client.find_post(1234567890).text
      def find_post(id, **params)
        Post.find(id, client: self, **params)
      end

      # Look up many posts by identifier, in parallel batches
      #
      # @api public
      # @param ids [Array<String, Integer, Post>] the identifiers
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Post>] the posts that were found
      # @example Look up many posts
      #   client.find_posts([1234567890, 1234567891])
      def find_posts(ids, **params)
        Post.find_all(ids, client: self, **params)
      end

      # Search recent posts
      #
      # @api public
      # @param query [String] the search query
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print posts about Ruby
      #   client.search("ruby -is:retweet").each { |post| puts post.text }
      def search(query, **params)
        Post.search(query, client: self, **params)
      end

      # Search the full archive of posts
      #
      # @api public
      # @param query [String] the search query
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print every post about Ruby
      #   client.search_all("ruby -is:retweet").each { |post| puts post.text }
      def search_all(query, **params)
        Post.search_all(query, client: self, **params)
      end

      # Create a post as the authenticated user
      #
      # @api public
      # @param text [String] the text of the post
      # @param params [Hash] additional request body fields, such as reply or media
      # @return [Post, nil] the created post, holding only its identifier and text
      # @example Create a post
      #   client.create_post("Hello, World!")
      def create_post(text, **params)
        Post.create(text, client: self, **params)
      end

      # Delete a post as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @return [Boolean] true if the post was deleted
      # @example Delete a post
      #   client.delete_post("1234567890")
      def delete_post(post)
        Post.delete(post, client: self)
      end

      # Look up a list by identifier
      #
      # @api public
      # @param id [String, Integer, List] the identifier
      # @param params [Hash] query parameters merged over the default parameters
      # @return [List, nil] the list or nil if the list was not found
      # @example Look up a list
      #   client.find_list(1234567890).name
      def find_list(id, **params)
        List.find(id, client: self, **params)
      end

      # Look up a space by identifier
      #
      # @api public
      # @param id [String, Integer, Space] the identifier
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Space, nil] the space or nil if the space was not found
      # @example Look up a space
      #   client.find_space("1DXxyRYNejbKM").title
      def find_space(id, **params)
        Space.find(id, client: self, **params)
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

      # Send a direct message to a user as the authenticated user
      #
      # @api public
      # @param to [User, String, Integer] the recipient or their identifier
      # @param text [String] the text of the message
      # @param params [Hash] additional request body fields, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers
      # @example Send a direct message
      #   client.create_direct_message(to: user, text: "Hello!")
      def create_direct_message(to:, text:, **params)
        DirectMessage.create(to:, text:, client: self, **params)
      end

      # Follow a user as the authenticated user
      #
      # @api public
      # @param user [User, String, Integer] the user or their identifier
      # @return [Boolean] true if the authenticated user now follows the user
      # @example Follow a user
      #   client.follow("7505382")
      def follow(user)
        current_user.follow(user)
      end

      # Unfollow a user as the authenticated user
      #
      # @api public
      # @param user [User, String, Integer] the user or their identifier
      # @return [Boolean] true if the authenticated user no longer follows the user
      # @example Unfollow a user
      #   client.unfollow("7505382")
      def unfollow(user)
        current_user.unfollow(user)
      end

      # Like a post as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @return [Boolean] true if the authenticated user now likes the post
      # @example Like a post
      #   client.like("1234567890")
      def like(post)
        current_user.like(post)
      end

      # Unlike a post as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @return [Boolean] true if the authenticated user no longer likes the post
      # @example Unlike a post
      #   client.unlike("1234567890")
      def unlike(post)
        current_user.unlike(post)
      end

      # Repost a post as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @return [Boolean] true if the authenticated user has reposted the post
      # @example Repost a post
      #   client.repost("1234567890")
      def repost(post)
        current_user.repost(post)
      end

      # Undo a repost as the authenticated user
      #
      # @api public
      # @param post [Post, String, Integer] the post or its identifier
      # @return [Boolean] true if the authenticated user no longer reposts the post
      # @example Undo a repost
      #   client.unrepost("1234567890")
      def unrepost(post)
        current_user.unrepost(post)
      end

      alias_method :tweet, :find_post
      alias_method :tweets, :find_posts
      alias_method :create_tweet, :create_post
      alias_method :delete_tweet, :delete_post
      alias_method :retweet, :repost
      alias_method :unretweet, :unrepost

      private

      # The authenticated user, fetched once per client
      # @api private
      # @return [User] the authenticated user
      # @raise [KeyError] if the API returns no user
      def current_user
        @current_user ||= me || raise(KeyError, "users/me returned no user")
      end
    end
  end
end
