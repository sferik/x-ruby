# frozen_string_literal: true

require_relative "batch_finders"
require_relative "cursor"
require_relative "resource"

module X
  module Objects
    # A live audio space
    #
    # The space endpoints take only app-only authentication, so a client that signs with OAuth 1.0a reads spaces with a
    # copy that authenticates as the app, while the spaces and posts it reads hold the client, so that they act as the
    # user.
    #
    # @api public
    class ::X::Space < Resource
      extend BatchFinders

      # Every public space field
      #
      # A minor release may add to it the fields the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of fields of its own.
      FIELDS = %w[created_at ended_at id is_ticketed lang participant_count scheduled_start started_at state
        subscriber_count title updated_at].freeze
      # Every expansion available on space endpoints
      #
      # A minor release may add to it the expansions the API adds, so that a lookup asks for them too; see
      # {Resource#hydrated?} for what that means for a resource looked up with a list of expansions of its own.
      EXPANSIONS = %w[creator_id host_ids invited_user_ids speaker_ids topic_ids].freeze
      # Maximum number of posts or buyers per page, or of spaces a search returns
      MAX_RESULTS = 100
      private_constant :MAX_RESULTS

      class << self
        # The API endpoint used to look up spaces by identifier
        #
        # @api private
        # @return [String] the endpoint
        # @example Get the endpoint
        #   X::Space.__send__(:endpoint) # => "spaces"
        def endpoint
          "spaces"
        end

        # The type of the identifier, which is letters and digits rather than a number
        #
        # @api private
        # @return [Symbol] raw
        # @example Get the identifier type
        #   X::Space.__send__(:id_type) # => :raw
        def id_type = :raw

        # The client a space lookup requests with
        #
        # The space endpoints refuse OAuth 1.0a, so a client that signs with it looks spaces up with a copy that
        # reuses its bearer token, as a client signed in with OAuth 2.0 as a user that holds the app's credentials does.
        # One that holds none looks them up as it is.
        #
        # @api private
        # @param client [Object] the client the lookup was given
        # @return [Object] the client's app-only client, or the client itself
        # @example Get the client a space lookup requests with
        #   X::Space.__send__(:client_for, client)
        def client_for(client) = Utils.space_client(client)

        # The query parameter that selects space fields
        #
        # @api private
        # @return [String] the fields parameter
        # @example Get the fields parameter
        #   X::Space.__send__(:fields_key) # => "space.fields"
        def fields_key = "space.fields"

        private :endpoint, :id_type, :client_for, :fields_key

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
          Cursor.__send__(:build, self, "spaces/search", client:, params: {query:, max_results: MAX_RESULTS}.merge(params), app_only: true)
        end
      end

      # Look up the live and scheduled spaces many users created, in parallel batches
      #
      # The API returns the spaces of up to 100 users at a time, in one response without pages, so the users are
      # looked up that many at a time.
      #
      # @api public
      # @param users [Array<User, String, Integer>] the users who created the spaces, or their identifiers
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Space>] the spaces, frozen, empty if the users created none
      # @raise [ArgumentError] if a user is not a user or the identifier of one, or the concurrency is less than one,
      #   before a request
      # @yieldparam problem [Problem] each problem the API reported
      # @example Print the spaces two users created
      #   X::Space.find_all_by_creator([7505382, 783214], client: client).each { |space| puts space.title }
      def self.find_all_by_creator(users, client:, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
        ids = users.map { |user| Utils.id_of(user, User) }
        spaces = lookup_in_batches("spaces/by/creator_ids", :user_ids, ids, client:, concurrency:, **params, &) #: Array[Space]
        spaces.freeze
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

      # @!attribute [r] ticketed
      #   Whether the space requires a ticket, the is_ticketed field
      #   @api public
      #   @return [Boolean, nil] true if the space is ticketed
      #   @example Check whether a space is ticketed
      #     space.ticketed?
      attribute :ticketed, :boolean, key: %w[is_ticketed]

      # @!method ticketed?
      #   Check whether the space requires a ticket
      #   @api public
      #   @return [Boolean] true if the space is ticketed
      #   @example Check whether a space is ticketed
      #     space.ticketed?

      # @!attribute [r] participant_count
      #   The number of participants
      #   @api public
      #   @return [Integer, nil] the participant count
      #   @example Get the participant count
      #     space.participant_count
      attribute :participant_count, :integer

      # @!attribute [r] subscriber_count
      #   The number of subscribers
      #   @api public
      #   @return [Integer, nil] the subscriber count
      #   @example Get the subscriber count
      #     space.subscriber_count
      attribute :subscriber_count, :integer

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
      #   @return [Array<Integer>] the host identifiers, empty if there are none
      #   @example Get the host identifiers
      #     space.host_ids
      attribute :host_ids, :integers

      # @!attribute [r] speaker_ids
      #   The identifiers of the speakers
      #   @api public
      #   @return [Array<Integer>] the speaker identifiers, empty if there are none
      #   @example Get the speaker identifiers
      #     space.speaker_ids
      attribute :speaker_ids, :integers

      # @!attribute [r] invited_user_ids
      #   The identifiers of the invited users
      #   @api public
      #   @return [Array<Integer>] the invited user identifiers, empty if there are none
      #   @example Get the invited user identifiers
      #     space.invited_user_ids
      attribute :invited_user_ids, :integers

      # @!attribute [r] topic_ids
      #   The identifiers of the topics
      #   @api public
      #   @return [Array<Integer>] the topic identifiers, empty if there are none
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

      # The posts shared in this space
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the posts
      # @example Print the shared posts
      #   space.posts.each { |post| puts post.text }
      def posts(**params)
        cursor(Post, "spaces/#{id}/tweets", max_results: MAX_RESULTS, app_only: true, **params)
      end

      # The users who bought a ticket to this space
      #
      # The authenticated user must have created the space. The endpoint takes only OAuth 2.0 user context, which the object layer cannot route around, so a client that
      # signs with OAuth 1.0a, or authenticates as the app, is refused.
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the buyers
      # @example Print the buyers of a ticketed space
      #   space.buyers.each { |user| puts user.username }
      def buyers(**params) = cursor(User, "spaces/#{id}/buyers", max_results: MAX_RESULTS, **params)

      alias_method :tweets, :posts
    end
  end
end
