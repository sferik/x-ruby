require "uri"
require_relative "relationships"
require_relative "cursor"
require_relative "resource"
require_relative "user_finders"

module X
  # A user account
  # @api public
  class User < Objects::Resource
    include Objects::Relationships
    extend Objects::UserFinders

    # Every public user field; the identifiers of referenced posts come with their expansions
    FIELDS = %w[created_at description entities id location name profile_image_url protected public_metrics url
      username verified verified_type withheld].freeze
    # Every expansion available on user endpoints that refers to a modeled resource
    EXPANSIONS = %w[most_recent_post_id pinned_post_id].freeze
    # Maximum number of followers or followed users per page
    MAX_FOLLOW_RESULTS = 1000
    # Maximum number of posts or lists per page
    MAX_RESULTS = 100
    # Maximum number of users per page of a user search
    MAX_SEARCH_RESULTS = 1000

    class << self
      # The API endpoint used to look up users by identifier
      #
      # @api private
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::User.endpoint # => "users"
      def endpoint = "users"

      # The key under which users appear in the includes of a response
      #
      # @api private
      # @return [String] the includes key
      # @example Get the includes key
      #   X::User.includes_key # => "users"
      def includes_key = "users"

      # The query parameter that selects user fields
      #
      # @api private
      # @return [String] the fields parameter
      # @example Get the fields parameter
      #   X::User.fields_key # => "user.fields"
      def fields_key = "user.fields"

      # The default query parameters requesting every user field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::User.default_params["user.fields"]
      def default_params
        {"user.fields" => FIELDS, "post.fields" => Post::FIELDS, "expansions" => EXPANSIONS}
      end

      # Search users
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching users
      # @example Print the users matching a query
      #   X::User.search("ruby", client: client).each { |user| puts user.username }
      def search(query, client:, **params)
        Cursor.new(self, "users/search", client:, params: {query:, max_results: MAX_SEARCH_RESULTS}.merge(params), token_param: "next_token")
      end

      # Look up the authenticated user
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the authenticated user
      # @yieldparam problem [Problem] each problem the API reported
      # @example Look up the authenticated user
      #   X::User.current(client: client)
      def current(client:, **params, &)
        lookup("users/me", client:, **params, &)
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

    # @!attribute [r] connection_status
    #   How the authenticated user and this user are connected
    #   @api public
    #   @return [Array<String>, nil] following, followed_by, blocking, muting, follow_request_sent, or follow_request_received
    #   @example Check whether this user follows the authenticated user
    #     client.find_user("sferik", "user.fields": "connection_status").connection_status.include?("followed_by")
    attribute :connection_status

    # @!attribute [r] pinned_post_id
    #   The identifier of the pinned post
    #   @api public
    #   @return [Integer, nil] the pinned post identifier
    #   @example Get the pinned post identifier
    #     user.pinned_post_id
    attribute :pinned_post_id, :integer

    # @!attribute [r] most_recent_post_id
    #   The identifier of the most recent post
    #   @api public
    #   @return [Integer, nil] the most recent post identifier
    #   @example Get the most recent post identifier
    #     user.most_recent_post_id
    attribute :most_recent_post_id, :integer

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
    attribute :post_count, key: %w[public_metrics post_count]

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

    # @!attribute [r] media_count
    #   The number of photos and videos the user has posted
    #   @api public
    #   @return [Integer, nil] the media count
    #   @example Get the media count
    #     user.media_count
    attribute :media_count, key: %w[public_metrics media_count]

    # @!method pinned_post
    #   The pinned post, from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [Post, nil] the pinned post
    #   @example Get the pinned post
    #     user.pinned_post
    reference :pinned_post, :Post, key: %w[pinned_post_id]

    # @!method most_recent_post
    #   The most recent post, from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [Post, nil] the most recent post
    #   @example Get the most recent post
    #     user.most_recent_post
    reference :most_recent_post, :Post, key: %w[most_recent_post_id]

    alias_method :tweet_count, :post_count
    alias_method :pinned_tweet_id, :pinned_post_id
    alias_method :most_recent_tweet_id, :most_recent_post_id
    alias_method :pinned_tweet, :pinned_post
    alias_method :most_recent_tweet, :most_recent_post

    # The permalink of the profile, by username when known and by identifier otherwise
    #
    # @api public
    # @return [String] the x.com address of the profile
    # @example Get the permalink
    #   user.permalink # => "https://x.com/sferik"
    def permalink = "https://x.com/#{username || "i/user/#{id}"}"

    # The permalink of the user as a URI
    #
    # @api public
    # @return [URI::Generic] the x.com address of the user
    # @example Get the address as a URI
    #   user.uri # => #<URI::HTTPS https://x.com/sferik>
    def uri = URI(permalink)

    # The users following this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followers
    # @example Print every follower
    #   user.followers.each { |follower| puts follower.username }
    def followers(**params)
      cursor(User, "users/#{id}/followers", max_results: MAX_FOLLOW_RESULTS, total: :followers_count, **params)
    end

    # The users this user follows
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followed users
    # @example Count the followed users
    #   user.following.count
    def following(**params)
      cursor(User, "users/#{id}/following", max_results: MAX_FOLLOW_RESULTS, total: :following_count, **params)
    end

    # The users this user blocks, which must be the authenticated user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the blocked users
    # @example Print every blocked user
    #   client.current_user.blocking.each { |user| puts user.username }
    def blocking(**params)
      cursor(User, "users/#{id}/blocking", max_results: MAX_FOLLOW_RESULTS, **params)
    end

    # The users this user mutes, which must be the authenticated user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the muted users
    # @example Print every muted user
    #   client.current_user.muting.each { |user| puts user.username }
    def muting(**params)
      cursor(User, "users/#{id}/muting", max_results: MAX_FOLLOW_RESULTS, **params)
    end

    # The posts by this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the posts
    # @example Print the most recent posts
    #   user.posts.first(10).each { |post| puts post.text }
    def posts(**params)
      cursor(Post, "users/#{id}/tweets", max_results: MAX_RESULTS, min_results: 5, **params)
    end

    # The home timeline of this user, which must be the authenticated user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the posts by the users this user follows, newest first
    # @example Print the home timeline
    #   client.current_user.home_timeline.first(10).each { |post| puts post.text }
    def home_timeline(**params)
      cursor(Post, "users/#{id}/timelines/reverse_chronological", max_results: MAX_RESULTS, **params)
    end

    # The posts mentioning this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the mentions
    # @example Print the most recent mentions
    #   user.mentions.first(10).each { |post| puts post.text }
    def mentions(**params)
      cursor(Post, "users/#{id}/mentions", max_results: MAX_RESULTS, min_results: 5, **params)
    end

    # The posts liked by this user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the liked posts
    # @example Print the most recently liked posts
    #   user.liked_posts.first(10).each { |post| puts post.text }
    def liked_posts(**params)
      cursor(Post, "users/#{id}/liked_tweets", max_results: MAX_RESULTS, min_results: 5, **params)
    end

    # The posts bookmarked by the authenticated user
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the bookmarked posts
    # @example Print the bookmarked posts
    #   client.current_user.bookmarks.each { |post| puts post.text }
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
      cursor(List, "users/#{id}/list_memberships", max_results: MAX_RESULTS, total: :listed_count, **params)
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

    # The lists this user has pinned
    #
    # The API returns them in one response, without pages.
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the pinned lists
    # @example Print the pinned lists
    #   client.current_user.pinned_lists.each { |list| puts list.name }
    def pinned_lists(**params)
      cursor(List, "users/#{id}/pinned_lists", max_results: nil, **params)
    end

    alias_method :tweets, :posts
    alias_method :liked_tweets, :liked_posts
  end
end
