require_relative "cursor"
require_relative "resource"

module X
  # A live audio space
  # @api public
  class Space < Objects::Resource
    # Every public space field
    FIELDS = %w[created_at ended_at id is_ticketed lang participant_count scheduled_start started_at state
      subscriber_count title updated_at].freeze
    # Every expansion available on space endpoints
    EXPANSIONS = %w[creator_id host_ids invited_user_ids speaker_ids topic_ids].freeze
    # Maximum number of posts, or of spaces a search returns, per page
    MAX_RESULTS = 100

    class << self
      # The API endpoint used to look up spaces by identifier
      #
      # @api private
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::Space.endpoint # => "spaces"
      def endpoint
        "spaces"
      end

      # The type of the identifier, which is letters and digits rather than a number
      #
      # @api private
      # @return [Symbol] raw
      # @example Get the identifier type
      #   X::Space.id_type # => :raw
      def id_type = :raw

      # The query parameter that selects space fields
      #
      # @api private
      # @return [String] the fields parameter
      # @example Get the fields parameter
      #   X::Space.fields_key # => "space.fields"
      def fields_key = "space.fields"

      # The default query parameters requesting every space field and user expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::Space.default_params["space.fields"]
      def default_params
        {"space.fields" => FIELDS, "user.fields" => User::FIELDS, "expansions" => EXPANSIONS}
      end

      # Search spaces by their titles
      #
      # The API returns the matching spaces in one response, of up to 100 spaces.
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters, such as state: live or scheduled
      # @return [Cursor] a cursor over the matching spaces
      # @example Print the live spaces about Ruby
      #   X::Space.search("ruby", client: client, state: "live").each { |space| puts space.title }
      def search(query, client:, **params)
        Cursor.new(self, "spaces/search", client:, params: {query:, max_results: MAX_RESULTS}.merge(params))
      end
    end

    # @!attribute [r] title
    #   The title
    #   @api public
    #   @return [String, nil] the title
    #   @example Get the title
    #     space.title
    attribute :title

    # @!attribute [r] state
    #   The state: live, scheduled, or ended
    #   @api public
    #   @return [String, nil] the state
    #   @example Get the state
    #     space.state
    attribute :state

    # @!attribute [r] lang
    #   The BCP 47 language tag
    #   @api public
    #   @return [String, nil] the language tag
    #   @example Get the language
    #     space.lang
    attribute :lang

    # @!attribute [r] created_at
    #   The time when the space was created
    #   @api public
    #   @return [Time, nil] the creation time
    #   @example Get the creation time
    #     space.created_at
    attribute :created_at, :time

    # @!attribute [r] started_at
    #   The time when the space started
    #   @api public
    #   @return [Time, nil] the start time
    #   @example Get the start time
    #     space.started_at
    attribute :started_at, :time

    # @!attribute [r] ended_at
    #   The time when the space ended
    #   @api public
    #   @return [Time, nil] the end time
    #   @example Get the end time
    #     space.ended_at
    attribute :ended_at, :time

    # @!attribute [r] scheduled_start
    #   The scheduled start time
    #   @api public
    #   @return [Time, nil] the scheduled start time
    #   @example Get the scheduled start time
    #     space.scheduled_start
    attribute :scheduled_start, :time

    # @!attribute [r] updated_at
    #   The time when the space was last updated
    #   @api public
    #   @return [Time, nil] the update time
    #   @example Get the update time
    #     space.updated_at
    attribute :updated_at, :time

    # @!attribute [r] is_ticketed
    #   Whether the space requires a ticket
    #   @api public
    #   @return [Boolean, nil] true if the space is ticketed
    #   @example Get the raw flag
    #     space.is_ticketed
    attribute :is_ticketed

    # @!attribute [r] participant_count
    #   The number of participants
    #   @api public
    #   @return [Integer, nil] the participant count
    #   @example Get the participant count
    #     space.participant_count
    attribute :participant_count

    # @!attribute [r] subscriber_count
    #   The number of subscribers
    #   @api public
    #   @return [Integer, nil] the subscriber count
    #   @example Get the subscriber count
    #     space.subscriber_count
    attribute :subscriber_count

    # @!attribute [r] creator_id
    #   The identifier of the creator
    #   @api public
    #   @return [Integer, nil] the creator identifier
    #   @example Get the creator identifier
    #     space.creator_id
    attribute :creator_id, :integer

    # @!attribute [r] host_ids
    #   The identifiers of the hosts
    #   @api public
    #   @return [Array<Integer>, nil] the host identifiers
    #   @example Get the host identifiers
    #     space.host_ids
    attribute :host_ids, :integers

    # @!attribute [r] speaker_ids
    #   The identifiers of the speakers
    #   @api public
    #   @return [Array<Integer>, nil] the speaker identifiers
    #   @example Get the speaker identifiers
    #     space.speaker_ids
    attribute :speaker_ids, :integers

    # @!attribute [r] invited_user_ids
    #   The identifiers of the invited users
    #   @api public
    #   @return [Array<Integer>, nil] the invited user identifiers
    #   @example Get the invited user identifiers
    #     space.invited_user_ids
    attribute :invited_user_ids, :integers

    # @!attribute [r] topic_ids
    #   The identifiers of the topics
    #   @api public
    #   @return [Array<Integer>, nil] the topic identifiers
    #   @example Get the topic identifiers
    #     space.topic_ids
    attribute :topic_ids, :integers

    # @!method creator
    #   The creator, resolved from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [User, nil] the creator
    #   @example Get the creator's username
    #     space.creator.username
    reference :creator, :User, key: %w[creator_id]

    # @!method hosts
    #   The hosts, resolved from the includes or as stubs holding only their identifiers
    #   @api public
    #   @return [Array<User>] the hosts
    #   @example Get the hosts
    #     space.hosts
    references :hosts, :User, key: %w[host_ids]

    # @!method speakers
    #   The speakers, from the includes or as stubs holding only their identifiers
    #   @api public
    #   @return [Array<User>] the speakers
    #   @example Get the speakers
    #     space.speakers
    references :speakers, :User, key: %w[speaker_ids]

    # @!method invited_users
    #   The invited users, from the includes or as stubs holding only their identifiers
    #   @api public
    #   @return [Array<User>] the invited users
    #   @example Get the invited users
    #     space.invited_users
    references :invited_users, :User, key: %w[invited_user_ids]

    # Check whether the space requires a ticket
    #
    # @api public
    # @return [Boolean] true if the space is ticketed
    # @example Check whether a space is ticketed
    #   space.ticketed?
    def ticketed? = is_ticketed.eql?(true)

    # The posts shared in this space
    #
    # @api public
    # @param params [Hash] query parameters merged over the default parameters
    # @return [Cursor] a cursor over the posts
    # @example Print the shared posts
    #   space.posts.each { |post| puts post.text }
    def posts(**params)
      cursor(Post, "spaces/#{id}/tweets", max_results: MAX_RESULTS, **params)
    end

    alias_method :tweets, :posts
  end
end
