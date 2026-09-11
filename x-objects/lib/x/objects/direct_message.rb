require "json"
require_relative "cursor"
require_relative "resource"

module X
  # A direct message event
  # @api public
  class DirectMessage < Objects::Resource
    # Every public direct message event field
    FIELDS = %w[attachments created_at dm_conversation_id event_type id participant_ids referenced_tweets
      sender_id text].freeze
    # Every expansion available on direct message endpoints
    EXPANSIONS = %w[attachments.media_keys participant_ids referenced_tweets.id sender_id].freeze
    # Maximum number of events per page
    MAX_RESULTS = 100

    class << self
      # The API endpoint used to look up direct message events by identifier
      #
      # @api public
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::DirectMessage.endpoint # => "dm_events"
      def endpoint
        "dm_events"
      end

      # The default query parameters requesting every direct message field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::DirectMessage.default_params["dm_event.fields"]
      def default_params
        {"dm_event.fields" => FIELDS, "user.fields" => User::FIELDS, "tweet.fields" => Post::FIELDS,
         "media.fields" => Media::FIELDS, "expansions" => EXPANSIONS}
      end

      # The most recent direct message events across every conversation
      #
      # @api public
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the events
      # @example Print the most recent direct messages
      #   X::DirectMessage.all(client: client).first(10).each { |message| puts message.text }
      def all(client:, **params)
        Cursor.new(self, client:, path: "dm_events", params: {max_results: MAX_RESULTS}.merge(params))
      end

      # The direct message events in the one-to-one conversation with a user
      #
      # @api public
      # @param user [User, String, Integer] the other participant or their identifier
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the events
      # @example Print the conversation with a user
      #   X::DirectMessage.with(user, client: client).each { |message| puts message.text }
      def with(user, client:, **params)
        path = "dm_conversations/with/#{Objects::Utils.id_of(user)}/dm_events"
        Cursor.new(self, client:, path:, params: {max_results: MAX_RESULTS}.merge(params))
      end

      # Send a direct message to a user as the authenticated user
      #
      # @api public
      # @param to [User, String, Integer] the recipient or their identifier
      # @param text [String] the text of the message
      # @param client [Object] the client used to make the request
      # @param params [Hash] additional request body fields, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers
      # @example Send a direct message
      #   X::DirectMessage.create(to: user, text: "Hello!", client: client)
      def create(to:, text:, client:, **params)
        path = "dm_conversations/with/#{Objects::Utils.id_of(to)}/messages"
        data = client.post(path, JSON.generate({text:, **params}), **Objects::Utils::JSON_CLASSES).to_h["data"]
        return unless data.is_a?(Hash)

        new({"id" => data["dm_event_id"], "dm_conversation_id" => data["dm_conversation_id"]}, client:)
      end
    end

    # @!attribute [r] text
    #   The text
    #   @api public
    #   @return [String, nil] the text
    #   @example Get the text
    #     message.text
    attribute :text

    # @!attribute [r] event_type
    #   The event type: MessageCreate, ParticipantsJoin, or ParticipantsLeave
    #   @api public
    #   @return [String, nil] the event type
    #   @example Get the event type
    #     message.event_type
    attribute :event_type

    # @!attribute [r] created_at
    #   The time when the event occurred
    #   @api public
    #   @return [Time, nil] the event time
    #   @example Get the event time
    #     message.created_at
    attribute :created_at, :time

    # @!attribute [r] sender_id
    #   The identifier of the sender
    #   @api public
    #   @return [String, nil] the sender identifier
    #   @example Get the sender identifier
    #     message.sender_id
    attribute :sender_id

    # @!attribute [r] dm_conversation_id
    #   The identifier of the conversation
    #   @api public
    #   @return [String, nil] the conversation identifier
    #   @example Get the conversation identifier
    #     message.dm_conversation_id
    attribute :dm_conversation_id

    # @!attribute [r] participant_ids
    #   The identifiers of the participants who joined or left
    #   @api public
    #   @return [Array<String>, nil] the participant identifiers
    #   @example Get the participant identifiers
    #     message.participant_ids
    attribute :participant_ids

    # @!attribute [r] referenced_tweets
    #   The referenced posts with their identifiers
    #   @api public
    #   @return [Array<Hash>, nil] the referenced posts
    #   @example Get the referenced posts
    #     message.referenced_tweets
    attribute :referenced_tweets

    # @!attribute [r] attachments
    #   The attachment keys
    #   @api public
    #   @return [Hash, nil] the attachments
    #   @example Get the attachments
    #     message.attachments
    attribute :attachments

    # @!method sender
    #   The sender, resolved from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [User, nil] the sender
    #   @example Get the sender's username
    #     message.sender.username
    reference :sender, :User, key: "sender_id"

    # @!method participants
    #   The participants who joined or left, from the includes or as stubs
    #   @api public
    #   @return [Array<User>] the participants
    #   @example Get the participants
    #     message.participants
    references :participants, :User, key: "participant_ids"

    # @!method media
    #   The attached media, from the includes or as stubs holding only their keys
    #   @api public
    #   @return [Array<Media>] the media
    #   @example Get the media URLs
    #     message.media.map(&:url)
    references :media, :Media, key: %w[attachments media_keys]

    # The referenced posts, resolved from the includes or built as stubs
    #
    # @api public
    # @return [Array<Post>] the referenced posts
    # @example Get the referenced posts
    #   message.referenced_posts
    def referenced_posts
      Array(referenced_tweets).filter_map do |reference|
        resolve(Post, reference["id"]) #: Post?
      end.freeze
    end

    alias_method :conversation_id, :dm_conversation_id
  end
end
