require "json"
require "uri"
require_relative "cursor"
require_relative "resource"

module X
  # A curated list of users
  # @api public
  class List < Objects::Resource
    # Every public list field
    FIELDS = %w[created_at description follower_count id member_count name private].freeze
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

      # The query parameter that selects list fields
      #
      # @api public
      # @return [String] the fields parameter
      # @example Get the fields parameter
      #   X::List.fields_key # => "list.fields"
      def fields_key = "list.fields"

      # The default query parameters requesting every list field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::List.default_params["list.fields"]
      def default_params
        {"list.fields" => FIELDS, "user.fields" => User::FIELDS, "expansions" => EXPANSIONS}
      end

      # Create a list owned by the authenticated user
      #
      # @api public
      # @param name [String] the name of the list
      # @param client [Object] the client used to make the request
      # @param params [Hash] additional request body fields: description and private
      # @return [List, nil] the created list, holding only its identifier and name
      # @example Create a private list
      #   X::List.create("Rubyists", client: client, description: "People who write Ruby", private: true)
      def create(name, client:, **params)
        body = client.post("lists", JSON.generate({name:, **params}), **Objects::Utils::JSON_CLASSES)
        resource_from_response(body, client:)
      end

      # Refuse a batch lookup, which the API does not offer for lists
      #
      # @api public
      # @param ids [Array<String, Integer, List>] the identifiers
      # @param client [Object] the client, which is not used
      # @return [void]
      # @raise [UnsupportedOperation] always, since lists can only be looked up one at a time
      # @example Look lists up one at a time instead
      #   ids.map { |id| X::List.find(id, client: client) }
      def find_all(ids, client:, **)
        raise UnsupportedOperation, "#{self} cannot be fetched in batches; find #{ids.size} lists one at a time"
      end

      # Delete a list as the authenticated user
      #
      # @api public
      # @param list [List, String, Integer] the list or its identifier
      # @param client [Object] the client used to make the request
      # @return [Boolean] true if the list was deleted
      # @example Delete a list
      #   X::List.delete("1234567890", client: client)
      def delete(list, client:)
        body = client.delete("lists/#{Objects::Utils.id_of(list)}", **Objects::Utils::JSON_CLASSES)
        body.to_h.dig("data", "deleted").eql?(true)
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
    #   @return [Integer, nil] the owner identifier
    #   @example Get the owner identifier
    #     list.owner_id
    attribute :owner_id, :integer

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
    reference :owner, :User, key: %w[owner_id]

    # The members of this list
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the members
    # @example Print every member
    #   list.members.each { |user| puts user.username }
    def members(**params)
      cursor(User, "lists/#{id}/members", max_results: MAX_RESULTS, total: :member_count, **params)
    end

    # The followers of this list
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the followers
    # @example Print every follower
    #   list.followers.each { |user| puts user.username }
    def followers(**params)
      cursor(User, "lists/#{id}/followers", max_results: MAX_RESULTS, total: :follower_count, **params)
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

    # Check whether a user is a member of this list, scanning until one matches
    #
    # The API has no lookup for a membership, so this scans either the members of the list or the lists
    # the user is on. A private list scans its members, since a user's memberships leave private lists
    # out. A public list scans the lists the user is on when there are fewer of them than members, as its
    # member_count and the user's listed_count tell, looking up the list or the user first when either is
    # a stub. The API bills every resource a scan returns.
    #
    # @api public
    # @param user [User, String, Integer] the user or their identifier
    # @return [Boolean] true if the user is a member
    # @example Check whether a user is on a list
    #   list.member?(user)
    def member?(user)
      return members.stubs.include?(User.from_id(user)) unless fewer_memberships?(user)

      User.from_id(user, client: client!).list_memberships.stubs.include?(self)
    end

    # The permalink of the list
    #
    # @api public
    # @return [String] the x.com address of the list
    # @example Get the permalink
    #   list.permalink # => "https://x.com/i/lists/1234567890"
    def permalink = "https://x.com/i/lists/#{id}"

    # The permalink of the list as a URI
    #
    # @api public
    # @return [URI::Generic] the x.com address of the list
    # @example Get the address as a URI
    #   list.uri # => #<URI::HTTPS https://x.com/i/lists/1234567890>
    def uri = URI(permalink)

    # Add a member to this list as the authenticated user
    #
    # @api public
    # @param user [User, String, Integer] the user or their identifier
    # @return [Boolean] true if the user is now a member
    # @example Add a member
    #   list.add_member(user)
    def add_member(user)
      body = client!.post("lists/#{id}/members", JSON.generate({user_id: Objects::Utils.id_of(user)}), **Objects::Utils::JSON_CLASSES)
      body.to_h.dig("data", "is_member").eql?(true)
    end

    # Remove a member from this list as the authenticated user
    #
    # @api public
    # @param user [User, String, Integer] the user or their identifier
    # @return [Boolean] true if the user is no longer a member
    # @example Remove a member
    #   list.remove_member(user)
    def remove_member(user)
      body = client!.delete("lists/#{id}/members/#{Objects::Utils.id_of(user)}", **Objects::Utils::JSON_CLASSES)
      body.to_h.dig("data", "is_member").eql?(false)
    end

    # Delete this list as the authenticated user
    #
    # @api public
    # @return [Boolean] true if the list was deleted
    # @example Delete a list
    #   list.delete
    def delete
      self.class.delete(self, client: client!)
    end

    alias_method :tweets, :posts

    private

    # Check whether the user is on fewer lists than this public list has members
    # @api private
    # @param user [User, String, Integer] the user or their identifier
    # @return [Boolean] true if the lists the user is on are fewer than the members of this public list
    def fewer_memberships?(user)
      list = hydrate
      return false if list.nil? || list.private?

      member_count = list.member_count
      return false if member_count.nil?

      listed_count = listed_count_of(user)
      !listed_count.nil? && listed_count < member_count
    end

    # The number of lists a user is on, looking up a user that is not hydrated
    # @api private
    # @param user [User, String, Integer] the user or their identifier
    # @return [Integer, nil] the listed count, or nil if the user was not found
    def listed_count_of(user)
      known = user if user.is_a?(User) && user.hydrated?
      (known || User.find(User.from_id(user), client: client!))&.listed_count
    end
  end
end
