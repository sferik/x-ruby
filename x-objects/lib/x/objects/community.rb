require "uri"
require_relative "cursor"
require_relative "resource"

module X
  # A community of users who post to one another
  # @api public
  class Community < Objects::Resource
    # Every public community field
    FIELDS = %w[access created_at description id join_policy member_count name].freeze
    # Maximum number of communities per page of a search
    MAX_RESULTS = 100

    class << self
      # The API endpoint used to look up communities by identifier
      #
      # @api public
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::Community.endpoint # => "communities"
      def endpoint = "communities"

      # The query parameter that selects community fields
      #
      # @api public
      # @return [String] the fields parameter
      # @example Get the fields parameter
      #   X::Community.fields_key # => "community.fields"
      def fields_key = "community.fields"

      # The default query parameters requesting every community field
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::Community.default_params["community.fields"]
      def default_params = {"community.fields" => FIELDS}

      # Search communities
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching communities
      # @example Print the communities matching a query
      #   X::Community.search("ruby", client: client).each { |community| puts community.name }
      def search(query, client:, **params)
        Cursor.new(self, "communities/search", client:, params: {query:, max_results: MAX_RESULTS}.merge(params),
          token_param: "next_token", min_results: 10)
      end

      # Refuse a batch lookup, which the API does not offer for communities
      #
      # @api public
      # @param ids [Array<String, Integer, Community>] the identifiers
      # @param client [Object] the client, which is not used
      # @return [void]
      # @raise [UnsupportedOperation] always, since communities can only be looked up one at a time
      # @example Look communities up one at a time instead
      #   ids.map { |id| X::Community.find(id, client: client) }
      def find_all(ids, client:, **)
        raise UnsupportedOperation, "#{self} cannot be fetched in batches; find #{ids.size} communities one at a time"
      end
    end

    # @!attribute [r] name
    #   The name
    #   @api public
    #   @return [String, nil] the name
    #   @example Get the name
    #     community.name
    attribute :name

    # @!attribute [r] description
    #   The description
    #   @api public
    #   @return [String, nil] the description
    #   @example Get the description
    #     community.description
    attribute :description

    # @!attribute [r] created_at
    #   The creation time
    #   @api public
    #   @return [Time, nil] the creation time
    #   @example Get the creation time
    #     community.created_at
    attribute :created_at, :time

    # @!attribute [r] member_count
    #   The number of members
    #   @api public
    #   @return [Integer, nil] the member count
    #   @example Get the member count
    #     community.member_count
    attribute :member_count

    # @!attribute [r] access
    #   Who can see the community's posts, as the API names it
    #   @api public
    #   @return [String, nil] the access level
    #   @example Get the access level
    #     community.access
    attribute :access

    # @!attribute [r] join_policy
    #   How users become members, as the API names it
    #   @api public
    #   @return [String, nil] the join policy
    #   @example Get the join policy
    #     community.join_policy
    attribute :join_policy

    # The permalink of the community
    #
    # @api public
    # @return [String] the x.com address of the community
    # @example Get the permalink
    #   community.permalink # => "https://x.com/i/communities/1234567890"
    def permalink = "https://x.com/i/communities/#{id}"

    # The permalink of the community as a URI
    #
    # @api public
    # @return [URI::Generic] the x.com address of the community
    # @example Get the address as a URI
    #   community.uri # => #<URI::HTTPS https://x.com/i/communities/1234567890>
    def uri = URI(permalink)
  end
end
