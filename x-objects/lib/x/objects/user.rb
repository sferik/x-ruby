# frozen_string_literal: true

require "uri"
require_relative "relationships"
require_relative "cursor"
require_relative "resource"
require_relative "user_collections"
require_relative "user_finders"

module X
  module Objects
    # A user account
    # @api public
    class ::X::User < Resource
      include Relationships
      include UserCollections
      extend UserFinders

      # The user fields the object layer requests: every one that does not depend on who is authenticated, since a
      # field that does, such as connection_status, would make every request fail for a client that cannot read it;
      # the identifiers of referenced posts, and the affiliation, come with their expansions
      #
      # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
      FIELDS = %w[created_at description entities id is_identity_verified location name parody profile_banner_url
        profile_image_url protected public_metrics subscriber_count subscription_type url username verified
        verified_followers_count verified_type withheld].freeze
      # Every expansion available on user endpoints
      #
      # The API gives a user its affiliation when a request asks for the affiliation expansion, which it takes only
      # at the endpoints whose data is users, so the users a post, a list, a space, or a direct message includes hold
      # none, and hydrate looks them up with it.
      #
      # A minor release may add to it the expansions the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of expansions of its own.
      EXPANSIONS = %w[affiliation most_recent_post_id pinned_post_id].freeze
      # Maximum number of users per page of a user search
      MAX_SEARCH_RESULTS = 1000
      private_constant :MAX_SEARCH_RESULTS

      class << self
        # The API endpoint used to look up users by identifier
        #
        # @api private
        # @return [String] the endpoint
        # @example Get the endpoint
        #   X::User.__send__(:endpoint) # => "users"
        def endpoint = "users"

        # The key under which users appear in the includes of a response
        #
        # @api private
        # @return [String] the includes key
        # @example Get the includes key
        #   X::User.__send__(:includes_key) # => "users"
        def includes_key = "users"

        # The query parameter that selects user fields
        #
        # @api private
        # @return [String] the fields parameter
        # @example Get the fields parameter
        #   X::User.__send__(:fields_key) # => "user.fields"
        def fields_key = "user.fields"

        private :endpoint, :includes_key, :fields_key

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
          Cursor.__send__(:build, self, "users/search", client:, params: {query:, max_results: MAX_SEARCH_RESULTS}.merge(params), token_param: "next_token")
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

      # @!attribute [r] profile_banner_url
      #   The profile banner URL
      #   @api public
      #   @return [String, nil] the profile banner URL
      #   @example Get the profile banner URL
      #     user.profile_banner_url
      attribute :profile_banner_url

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

      # @!attribute [r] parody
      #   Whether the account labels itself a parody
      #   @api public
      #   @return [Boolean, nil] true if the account is labelled a parody
      #   @example Check whether a user is a parody account
      #     user.parody?
      attribute :parody, :boolean

      # @!method parody?
      #   Check whether the account labels itself a parody
      #   @api public
      #   @return [Boolean] true if the account is labelled a parody
      #   @example Leave out the parody accounts
      #     users.reject(&:parody?)

      # @!attribute [r] identity_verified
      #   Whether the account's identity is verified, the is_identity_verified field
      #   @api public
      #   @return [Boolean, nil] true if the identity is verified
      #   @example Check whether a user's identity is verified
      #     user.identity_verified?
      attribute :identity_verified, :boolean, key: %w[is_identity_verified]

      # @!method identity_verified?
      #   Check whether the account's identity is verified
      #   @api public
      #   @return [Boolean] true if the identity is verified
      #   @example Check whether a user's identity is verified
      #     user.identity_verified?

      # @!attribute [r] subscription_type
      #   The subscription the account pays for: Basic, Premium, PremiumPlus, or None
      #   @api public
      #   @return [String, nil] the subscription type
      #   @example Get the subscription type
      #     user.subscription_type
      attribute :subscription_type

      # @!attribute [r] affiliation
      #   The organization the account is affiliated with, with its badge
      #
      #   The API gives it for the affiliation expansion, which only the endpoints whose data is users take, so a user
      #   a post, a list, a space, or a direct message includes holds none until it is hydrated.
      #
      #   @api public
      #   @return [Hash, nil] the affiliation, with its description, url, badge_url, and user_id
      #   @example Get the affiliated organization
      #     user.affiliation&.fetch("description")
      attribute :affiliation, :object

      # @!attribute [r] affiliated_with_ids
      #   The identifiers of the accounts this account is affiliated with
      #   @api public
      #   @return [Array<Integer>] the identifiers, empty if there are none
      #   @example Get the identifiers of the accounts it is affiliated with
      #     user.affiliated_with_ids
      attribute :affiliated_with_ids, :integers, key: %w[affiliation user_id]

      # @!attribute [r] verified_followers_count
      #   The number of verified followers
      #   @api public
      #   @return [Integer, nil] the verified follower count
      #   @example Get the verified follower count
      #     user.verified_followers_count
      attribute :verified_followers_count, :integer

      # @!attribute [r] subscriber_count
      #   The number of users who subscribe to the user
      #   @api public
      #   @return [Integer, nil] the subscriber count
      #   @example Get the subscriber count
      #     user.subscriber_count
      attribute :subscriber_count, :integer

      # @!attribute [r] connection_status
      #   How the authenticated user and this user are connected
      #
      #   No lookup asks for it unless user.fields names it, so a user looked up otherwise holds none, and reads nil
      #   rather than an empty list, which would say the users are not connected.
      #
      #   @api public
      #   @return [Array<String>, nil] following, followed_by, blocking, muting, follow_request_sent, or
      #     follow_request_received, or nil when the response holds none
      #   @example Check whether this user follows the authenticated user
      #     client.find_user("sferik", "user.fields": "connection_status").connection_status.include?("followed_by")
      attribute :connection_status, :requested_list

      # @!attribute [r] receives_your_dm
      #   Whether the authenticated user can send this user a direct message
      #
      #   It depends on who is authenticated, so no lookup asks for it unless user.fields names it, and a user looked
      #   up otherwise holds none, and reads nil rather than false, which would say the user receives none.
      #
      #   @api public
      #   @return [Boolean, nil] true if the authenticated user can send this user a direct message, or nil when the
      #     response holds none
      #   @example Check whether a user can be sent a direct message
      #     client.find_user("sferik", "user.fields": "receives_your_dm").receives_your_dm?
      attribute :receives_your_dm, :boolean

      # @!method receives_your_dm?
      #   Check whether the authenticated user can send this user a direct message
      #
      #   A user whose response holds no receives_your_dm, such as one looked up without asking for it, is not known to
      #   receive one, and reads false.
      #
      #   @api public
      #   @return [Boolean] true if the response says the authenticated user can send this user a direct message
      #   @example Message the users who can be sent one
      #     users.select(&:receives_your_dm?).each { |user| client.create_dm(user, "Hello!") }

      # @!attribute [r] subscribes_to_you
      #   Whether this user subscribes to the authenticated user
      #
      #   It depends on who is authenticated, so no lookup asks for it unless user.fields names it, and a user looked
      #   up otherwise holds none, and reads nil rather than false.
      #
      #   @api public
      #   @return [Boolean, nil] true if this user subscribes to the authenticated user, or nil when the response holds
      #     none
      #   @example Check whether a user subscribes to the authenticated user
      #     client.find_user("sferik", "user.fields": "subscribes_to_you").subscribes_to_you?
      attribute :subscribes_to_you, :boolean

      # @!method subscribes_to_you?
      #   Check whether this user subscribes to the authenticated user
      #
      #   A user whose response holds no subscribes_to_you, such as one looked up without asking for it, reads false.
      #
      #   @api public
      #   @return [Boolean] true if the response says this user subscribes to the authenticated user
      #   @example Find the subscribers among some users
      #     users.select(&:subscribes_to_you?)

      # @!attribute [r] subscription
      #   The subscription between this user and the authenticated user
      #
      #   It depends on who is authenticated, so no lookup asks for it unless user.fields names it, and a user looked
      #   up otherwise holds none.
      #
      #   @api public
      #   @return [Hash, nil] the subscription, with subscribes_to_you, or nil when the response holds none
      #   @example Check whether a user subscribes to the authenticated user
      #     client.find_user("sferik", "user.fields": "subscription").subscription&.fetch("subscribes_to_you")
      attribute :subscription, :object

      # @!attribute [r] pinned_post_id
      #   The identifier of the pinned post
      #   @api public
      #   @return [Integer, nil] the pinned post identifier
      #   @example Get the pinned post identifier
      #     user.pinned_post_id
      attribute :pinned_post_id, :integer, tweet_key: %w[pinned_tweet_id]

      # @!attribute [r] most_recent_post_id
      #   The identifier of the most recent post
      #   @api public
      #   @return [Integer, nil] the most recent post identifier
      #   @example Get the most recent post identifier
      #     user.most_recent_post_id
      attribute :most_recent_post_id, :integer, tweet_key: %w[most_recent_tweet_id]

      # @!attribute [r] entities
      #   The entities found in the description and URL
      #   @api public
      #   @return [Hash, nil] the entities
      #   @example Get the entities
      #     user.entities
      attribute :entities, :object

      # @!attribute [r] withheld
      #   The withholding details
      #   @api public
      #   @return [Hash, nil] the withholding details
      #   @example Get the withholding details
      #     user.withheld
      attribute :withheld, :object

      # @!attribute [r] public_metrics
      #   The public metrics
      #   @api public
      #   @return [Hash, nil] the public metrics
      #   @example Get the public metrics
      #     user.public_metrics
      attribute :public_metrics, :object

      # @!attribute [r] followers_count
      #   The number of followers
      #   @api public
      #   @return [Integer, nil] the follower count
      #   @example Get the follower count
      #     user.followers_count
      attribute :followers_count, :integer, key: %w[public_metrics followers_count]

      # @!attribute [r] following_count
      #   The number of followed users
      #   @api public
      #   @return [Integer, nil] the following count
      #   @example Get the following count
      #     user.following_count
      attribute :following_count, :integer, key: %w[public_metrics following_count]

      # @!attribute [r] post_count
      #   The number of posts
      #   @api public
      #   @return [Integer, nil] the post count
      #   @example Get the post count
      #     user.post_count
      attribute :post_count, :integer, key: %w[public_metrics post_count], tweet_key: %w[public_metrics tweet_count]

      # @!attribute [r] listed_count
      #   The number of lists the user is a member of
      #   @api public
      #   @return [Integer, nil] the listed count
      #   @example Get the listed count
      #     user.listed_count
      attribute :listed_count, :integer, key: %w[public_metrics listed_count]

      # @!attribute [r] like_count
      #   The number of posts the user has liked
      #   @api public
      #   @return [Integer, nil] the like count
      #   @example Get the like count
      #     user.like_count
      attribute :like_count, :integer, key: %w[public_metrics like_count]

      # @!attribute [r] media_count
      #   The number of photos and videos the user has posted
      #   @api public
      #   @return [Integer, nil] the media count
      #   @example Get the media count
      #     user.media_count
      attribute :media_count, :integer, key: %w[public_metrics media_count]

      # @!method pinned_post
      #   The pinned post, from the includes or as a stub holding only its identifier
      #   @api public
      #   @return [Post, nil] the pinned post
      #   @example Get the pinned post
      #     user.pinned_post
      reference :pinned_post, :Post, key: %w[pinned_post_id], tweet_key: %w[pinned_tweet_id]

      # @!method most_recent_post
      #   The most recent post, from the includes or as a stub holding only its identifier
      #   @api public
      #   @return [Post, nil] the most recent post
      #   @example Get the most recent post
      #     user.most_recent_post
      reference :most_recent_post, :Post, key: %w[most_recent_post_id], tweet_key: %w[most_recent_tweet_id]

      # @!method affiliated_with
      #   The accounts this account is affiliated with, such as its organization
      #
      #   They come from the includes, or as stubs holding their identifiers. They point the other way from
      #   affiliates, the accounts affiliated with this one.
      #   @api public
      #   @return [Array<User>] the accounts it is affiliated with, empty if there are none
      #   @example Get the username of the affiliated organization
      #     user.affiliated_with.first&.hydrate&.username
      references :affiliated_with, :User, key: %w[affiliation user_id]

      attribute_alias :tweet_count, :post_count
      attribute_alias :pinned_tweet_id, :pinned_post_id
      attribute_alias :most_recent_tweet_id, :most_recent_post_id
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
    end
  end
end
