require_relative "actions"
require_relative "cursor"
require_relative "resource"

module X
  # A user account
  # @api public
  class User < Objects::Resource
    include Objects::Actions

    # Every public user field
    FIELDS = %w[created_at description entities id location most_recent_tweet_id name pinned_tweet_id
      profile_image_url protected public_metrics url username verified verified_type withheld].freeze
    # Every expansion available on user endpoints
    EXPANSIONS = %w[pinned_tweet_id].freeze
    # Maximum number of followers or followed users per page
    MAX_FOLLOW_RESULTS = 1000
    # Maximum number of posts or lists per page
    MAX_RESULTS = 100

    class << self
      # The API endpoint used to look up users by identifier
      #
      # @api public
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::User.endpoint # => "users"
      def endpoint
        "users"
      end

      # The key under which users appear in the includes of a response
      #
      # @api public
      # @return [String] the includes key
      # @example Get the includes key
      #   X::User.includes_key # => "users"
      def includes_key
        "users"
      end

      # The default query parameters requesting every user field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::User.default_params["user.fields"]
      def default_params
        {"user.fields" => FIELDS, "tweet.fields" => Post::FIELDS, "expansions" => EXPANSIONS}
      end

      # Look up a user by identifier or username
      #
      # An Integer or a user is looked up by identifier, and a String by username.
      #
      # @api public
      # @param id_or_username [Integer, User, String] an identifier or a user, or a username
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the user or nil if the user was not found
      # @example Look up a user by username
      #   X::User.find("sferik", client: client)
      def find(id_or_username, client:, **params)
        return super if Objects::Utils.id?(id_or_username) # steep:ignore ReturnTypeMismatch

        lookup("users/by/username/#{id_or_username}", client:, **params)
      end

      # Look up many users by identifier or username, in parallel batches
      #
      # Integers and users are looked up by identifier, and Strings by username.
      #
      # @api public
      # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found
      # @example Look up many users by username
      #   X::User.find_all(["sferik", "gem"], client: client)
      def find_all(ids_or_usernames, client:, **params)
        return super if ids_or_usernames.all? { |value| Objects::Utils.id?(value) } # steep:ignore ReturnTypeMismatch

        batches = ids_or_usernames.each_slice(Objects::Resource::MAX_BATCH_SIZE)
        Objects::Parallel.map(batches) { |batch| lookup_all("users/by", client:, usernames: batch, **params) }.flatten
      end

      # Look up the authenticated user
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the authenticated user
      # @example Look up the authenticated user
      #   X::User.me(client: client)
      def me(client:, **params)
        lookup("users/me", client:, **params)
      end
    end

    # @!attribute [r] name
    #   The display name
    #   @api public
    #   @return [String, nil] the display name
    #   @example Get the name
    #     user.name # => "Erik Berlin"
    attribute :name

    # @!attribute [r] username
    #   The handle, without the leading at sign
    #   @api public
    #   @return [String, nil] the username
    #   @example Get the username
    #     user.username # => "sferik"
    attribute :username

    # @!attribute [r] description
    #   The profile description
    #   @api public
    #   @return [String, nil] the description
    #   @example Get the description
    #     user.description
    attribute :description

    # @!attribute [r] location
    #   The profile location
    #   @api public
    #   @return [String, nil] the location
    #   @example Get the location
    #     user.location
    attribute :location

    # @!attribute [r] url
    #   The profile URL
    #   @api public
    #   @return [String, nil] the URL
    #   @example Get the URL
    #     user.url
    attribute :url

    # @!attribute [r] profile_image_url
    #   The profile image URL
    #   @api public
    #   @return [String, nil] the profile image URL
    #   @example Get the profile image URL
    #     user.profile_image_url
    attribute :profile_image_url

    # @!attribute [r] created_at
    #   The time when the account was created
    #   @api public
    #   @return [Time, nil] the creation time
    #   @example Get the creation time
    #     user.created_at
    attribute :created_at, :time

    # @!attribute [r] protected
    #   Whether the account's posts are protected
    #   @api public
    #   @return [Boolean, nil] true if the posts are protected
    #   @example Check whether a user is protected
    #     user.protected?
    attribute :protected, :boolean

    # @!method protected?
    #   Check whether the account's posts are protected
    #   @api public
    #   @return [Boolean] true if the posts are protected
    #   @example Check whether the account's posts are protected
    #     user.protected?

    # @!attribute [r] verified
    #   Whether the account is verified
    #   @api public
    #   @return [Boolean, nil] true if the account is verified
    #   @example Check whether a user is verified
    #     user.verified?
    attribute :verified, :boolean

    # @!method verified?
    #   Check whether the account is verified
    #   @api public
    #   @return [Boolean] true if the account is verified
    #   @example Check whether the account is verified
    #     user.verified?

    # @!attribute [r] verified_type
    #   The verification type: blue, business, government, or none
    #   @api public
    #   @return [String, nil] the verification type
    #   @example Get the verification type
    #     user.verified_type
    attribute :verified_type

    # @!attribute [r] pinned_post_id
    #   The identifier of the pinned post
    #   @api public
    #   @return [String, nil] the pinned post identifier
    #   @example Get the pinned post identifier
    #     user.pinned_post_id
    attribute :pinned_post_id, key: %w[pinned_tweet_id]

    # @!attribute [r] most_recent_post_id
    #   The identifier of the most recent post
    #   @api public
    #   @return [String, nil] the most recent post identifier
    #   @example Get the most recent post identifier
    #     user.most_recent_post_id
    attribute :most_recent_post_id, key: %w[most_recent_tweet_id]

    # @!attribute [r] entities
    #   The entities found in the description and URL
    #   @api public
    #   @return [Hash, nil] the entities
    #   @example Get the entities
    #     user.entities
    attribute :entities

    # @!attribute [r] withheld
    #   The withholding details
    #   @api public
    #   @return [Hash, nil] the withholding details
    #   @example Get the withholding details
    #     user.withheld
    attribute :withheld

    # @!attribute [r] public_metrics
    #   The public metrics
    #   @api public
    #   @return [Hash, nil] the public metrics
    #   @example Get the public metrics
    #     user.public_metrics
    attribute :public_metrics

    # @!attribute [r] followers_count
    #   The number of followers
    #   @api public
    #   @return [Integer, nil] the follower count
    #   @example Get the follower count
    #     user.followers_count
    attribute :followers_count, key: %w[public_metrics followers_count]

    # @!attribute [r] following_count
    #   The number of followed users
    #   @api public
    #   @return [Integer, nil] the following count
    #   @example Get the following count
    #     user.following_count
    attribute :following_count, key: %w[public_metrics following_count]

    # @!attribute [r] post_count
    #   The number of posts
    #   @api public
    #   @return [Integer, nil] the post count
    #   @example Get the post count
    #     user.post_count
    attribute :post_count, key: %w[public_metrics tweet_count]

    # @!attribute [r] listed_count
    #   The number of lists the user is a member of
    #   @api public
    #   @return [Integer, nil] the listed count
    #   @example Get the listed count
    #     user.listed_count
    attribute :listed_count, key: %w[public_metrics listed_count]

    # @!attribute [r] like_count
    #   The number of posts the user has liked
    #   @api public
    #   @return [Integer, nil] the like count
    #   @example Get the like count
    #     user.like_count
    attribute :like_count, key: %w[public_metrics like_count]

    # @!method pinned_post
    #   The pinned post, from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [Post, nil] the pinned post
    #   @example Get the pinned post
    #     user.pinned_post
    reference :pinned_post, :Post, key: "pinned_tweet_id"

    # @!method most_recent_post
    #   The most recent post, from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [Post, nil] the most recent post
    #   @example Get the most recent post
    #     user.most_recent_post
    reference :most_recent_post, :Post, key: "most_recent_tweet_id"

    alias_method :tweet_count, :post_count
    alias_method :pinned_tweet_id, :pinned_post_id
    alias_method :most_recent_tweet_id, :most_recent_post_id
    alias_method :pinned_tweet, :pinned_post
    alias_method :most_recent_tweet, :most_recent_post

    # The users following this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followers
    # @example Print every follower
    #   user.followers.each { |follower| puts follower.username }
    def followers(**params)
      cursor(User, "users/#{id}/followers", max_results: MAX_FOLLOW_RESULTS, **params)
    end

    # The users this user follows
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followed users
    # @example Count the followed users
    #   user.following.count
    def following(**params)
      cursor(User, "users/#{id}/following", max_results: MAX_FOLLOW_RESULTS, **params)
    end

    # The posts by this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the posts
    # @example Print the most recent posts
    #   user.posts.first(10).each { |post| puts post.text }
    def posts(**params)
      cursor(Post, "users/#{id}/tweets", max_results: MAX_RESULTS, **params)
    end

    # The posts mentioning this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the mentions
    # @example Print the most recent mentions
    #   user.mentions.first(10).each { |post| puts post.text }
    def mentions(**params)
      cursor(Post, "users/#{id}/mentions", max_results: MAX_RESULTS, **params)
    end

    # The posts liked by this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the liked posts
    # @example Print the most recently liked posts
    #   user.liked_posts.first(10).each { |post| puts post.text }
    def liked_posts(**params)
      cursor(Post, "users/#{id}/liked_tweets", max_results: MAX_RESULTS, **params)
    end

    # The posts bookmarked by the authenticated user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the bookmarked posts
    # @example Print the bookmarked posts
    #   client.me.bookmarks.each { |post| puts post.text }
    def bookmarks(**params)
      cursor(Post, "users/#{id}/bookmarks", max_results: MAX_RESULTS, **params)
    end

    # The lists owned by this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the owned lists
    # @example Print the owned lists
    #   user.owned_lists.each { |list| puts list.name }
    def owned_lists(**params)
      cursor(List, "users/#{id}/owned_lists", max_results: MAX_RESULTS, **params)
    end

    # The lists this user is a member of
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the list memberships
    # @example Print the list memberships
    #   user.list_memberships.each { |list| puts list.name }
    def list_memberships(**params)
      cursor(List, "users/#{id}/list_memberships", max_results: MAX_RESULTS, **params)
    end

    # The lists this user follows
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followed lists
    # @example Print the followed lists
    #   user.followed_lists.each { |list| puts list.name }
    def followed_lists(**params)
      cursor(List, "users/#{id}/followed_lists", max_results: MAX_RESULTS, **params)
    end

    alias_method :tweets, :posts
    alias_method :liked_tweets, :liked_posts
  end
end
