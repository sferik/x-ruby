require_relative "cursor"
require_relative "resource"

module X
  # A curated list of users
  # @api public
  class List < Objects::Resource
    # Every public list field
    FIELDS = %w[created_at description follower_count id member_count name owner_id private].freeze
    # Every expansion available on list endpoints
    EXPANSIONS = %w[owner_id].freeze
    # Maximum number of users or posts per page
    MAX_RESULTS = 100

    class << self
      # The API endpoint used to look up lists by identifier
      #
      # @api public
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::List.endpoint # => "lists"
      def endpoint
        "lists"
      end

      # The default query parameters requesting every list field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::List.default_params["list.fields"]
      def default_params
        {"list.fields" => FIELDS, "user.fields" => User::FIELDS, "expansions" => EXPANSIONS}
      end
    end

    # @!attribute [r] name
    #   The name
    #   @api public
    #   @return [String, nil] the name
    #   @example Get the name
    #     list.name
    attribute :name

    # @!attribute [r] description
    #   The description
    #   @api public
    #   @return [String, nil] the description
    #   @example Get the description
    #     list.description
    attribute :description

    # @!attribute [r] created_at
    #   The time when the list was created
    #   @api public
    #   @return [Time, nil] the creation time
    #   @example Get the creation time
    #     list.created_at
    attribute :created_at, :time

    # @!attribute [r] follower_count
    #   The number of followers
    #   @api public
    #   @return [Integer, nil] the follower count
    #   @example Get the follower count
    #     list.follower_count
    attribute :follower_count

    # @!attribute [r] member_count
    #   The number of members
    #   @api public
    #   @return [Integer, nil] the member count
    #   @example Get the member count
    #     list.member_count
    attribute :member_count

    # @!attribute [r] owner_id
    #   The identifier of the owner
    #   @api public
    #   @return [String, nil] the owner identifier
    #   @example Get the owner identifier
    #     list.owner_id
    attribute :owner_id

    # @!attribute [r] private
    #   Whether the list is private
    #   @api public
    #   @return [Boolean, nil] true if the list is private
    #   @example Check whether a list is private
    #     list.private?
    attribute :private, :boolean

    # @!method private?
    #   Check whether the list is private
    #   @api public
    #   @return [Boolean] true if the list is private
    #   @example Check whether the list is private
    #     list.private?

    # @!method owner
    #   The owner, resolved from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [User, nil] the owner
    #   @example Get the owner's username
    #     list.owner.username
    reference :owner, :User, key: "owner_id"

    # The members of this list
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the members
    # @example Print every member
    #   list.members.each { |user| puts user.username }
    def members(**params)
      cursor(User, "lists/#{id}/members", max_results: MAX_RESULTS, **params)
    end

    # The followers of this list
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followers
    # @example Print every follower
    #   list.followers.each { |user| puts user.username }
    def followers(**params)
      cursor(User, "lists/#{id}/followers", max_results: MAX_RESULTS, **params)
    end

    # The posts by members of this list
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the posts
    # @example Print the most recent posts
    #   list.posts.first(10).each { |post| puts post.text }
    def posts(**params)
      cursor(Post, "lists/#{id}/tweets", max_results: MAX_RESULTS, **params)
    end

    alias_method :tweets, :posts
  end
end
