# frozen_string_literal: true

require_relative "cursor"
require_relative "direct_message_conversations"
require_relative "resource"

module X
  # A direct message event
  # @api public
  class DirectMessage < Resource
    extend Objects::DirectMessageConversations

    # The direct message event fields the object layer requests; the sender, the participants, and the posts a
    # message refers to come with their expansions
    FIELDS = %w[attachments created_at dm_conversation_id entities event_type id text].freeze
    # Every expansion available on direct message endpoints
    EXPANSIONS = %w[attachments.media_keys participant_ids referenced_posts sender_id].freeze
    # Maximum number of events per page
    MAX_RESULTS = 100

    class << self
      # Check whether direct message events can be looked up many at a time
      #
      # The API offers no batch lookup of them, so each stub hydrates on its own.
      #
      # @api private
      # @return [Boolean] false
      # @example Check whether direct message events can be looked up in batches
      #   X::DirectMessage.batchable? # => false
      def batchable? = false

      # The API endpoint used to look up direct message events by identifier
      #
      # @api private
      # @return [String] the endpoint
      # @example Get the endpoint
      #   X::DirectMessage.endpoint # => "dm_events"
      def endpoint
        "dm_events"
      end

      # The query parameter that selects direct message event fields
      #
      # @api private
      # @return [String] the fields parameter
      # @example Get the fields parameter
      #   X::DirectMessage.fields_key # => "dm_event.fields"
      def fields_key = "dm_event.fields"

      # The default query parameters requesting every direct message field and expansion
      #
      # @api public
      # @return [Hash{String => Array<String>}] the default query parameters
      # @example Get the default parameters
      #   X::DirectMessage.default_params["dm_event.fields"]
      def default_params
        {"dm_event.fields" => FIELDS, "user.fields" => User::FIELDS, "post.fields" => Post::FIELDS,
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
        Cursor.new(self, "dm_events", client:, params: {max_results: MAX_RESULTS}.merge(params))
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
        Cursor.new(self, path, client:, params: {max_results: MAX_RESULTS}.merge(params))
      end

      # Send a direct message to a user as the authenticated user
      #
      # @api public
      # @param user [User, String, Integer] the recipient or their identifier
      # @param text [String, nil] the text of the message, or nil for a message of attachments alone
      # @param client [Object] the client used to make the request
      # @param media_ids [Array<String, Integer, #fetch, Media>, String, Integer, #fetch, Media, nil] the identifiers of
      #   uploaded media to attach, what the uploads returned, or media, such as that of a post, one or many
      # @param params [Hash] additional request body fields, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers
      # @raise [ArgumentError] if the message has neither text nor any other field, or has both media_ids and
      #   attachments
      # @example Send a direct message
      #   X::DirectMessage.create(user, "Hello!", client: client)
      # @example Send an image without text
      #   X::DirectMessage.create(user, client: client, media_ids: media)
      def create(user, text = nil, client:, media_ids: nil, **params)
        path = "dm_conversations/with/#{Objects::Utils.id_of(user)}/messages"
        sent(client.post(path, message(text, params, media_ids), **Objects::Utils::JSON_CLASSES), client:)
      end

      # Delete a direct message event as the authenticated user
      #
      # @api public
      # @param message [DirectMessage, String, Integer] the event or its identifier
      # @param client [Object] the client used to make the request
      # @return [Boolean] true if the event was deleted
      # @example Delete a direct message
      #   X::DirectMessage.delete("1234567890", client: client)
      def delete(message, client:)
        body = client.delete("dm_events/#{Objects::Utils.id_of(message)}", **Objects::Utils::JSON_CLASSES)
        body.to_h.dig("data", "deleted").eql?(true)
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
    #   @return [Integer, nil] the sender identifier
    #   @example Get the sender identifier
    #     message.sender_id
    attribute :sender_id, :integer

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
    #   @return [Array<Integer>, nil] the participant identifiers
    #   @example Get the participant identifiers
    #     message.participant_ids
    attribute :participant_ids, :integers

    # @!attribute [r] referenced_posts
    #   The referenced posts with their identifiers
    #   @api public
    #   @return [Array<Hash>, nil] the referenced posts
    #   @example Get the referenced posts
    #     message.referenced_posts
    attribute :referenced_posts

    # @!attribute [r] attachments
    #   The attachment keys
    #   @api public
    #   @return [Hash, nil] the attachments
    #   @example Get the attachments
    #     message.attachments
    attribute :attachments

    # @!attribute [r] entities
    #   The entities found in the text: its URLs, hashtags, mentions, and cashtags
    #   @api public
    #   @return [Hash, nil] the entities
    #   @example Get the URLs of a message
    #     message.entities&.fetch("urls")
    attribute :entities

    # @!method sender
    #   The sender, resolved from the includes or as a stub holding only its identifier
    #   @api public
    #   @return [User, nil] the sender
    #   @example Get the sender's username
    #     message.sender.username
    reference :sender, :User, key: %w[sender_id]

    # @!method participants
    #   The participants who joined or left, from the includes or as stubs
    #   @api public
    #   @return [Array<User>] the participants
    #   @example Get the participants
    #     message.participants
    references :participants, :User, key: %w[participant_ids]

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
    #   message.references
    def references
      Array(referenced_posts).filter_map do |reference|
        resolve(Post, reference["id"]) #: Post?
      end.freeze
    end

    # Check whether a user sent this message
    #
    # @api public
    # @param user [User, String, Integer] the user or their identifier
    # @return [Boolean] true if the user sent the message
    # @example Split messages into sent and received
    #   messages.partition { |message| message.from?(client.current_user!) }
    def from?(user) = sender_id.to_s.eql?(Objects::Utils.id_of(user))

    # Check whether the message belongs to a group conversation
    #
    # The identifier of a one-to-one conversation joins the identifiers of its two participants with a hyphen, and
    # the identifier of a group conversation is a number of its own.
    #
    # @api public
    # @return [Boolean] true if the message belongs to a group conversation, false if to a one-to-one conversation or
    #   the message does not say
    # @example Leave out the messages of group conversations
    #   client.direct_messages.reject(&:group?)
    def group?
      conversation_id = dm_conversation_id
      !conversation_id.nil? && !conversation_id.include?("-")
    end

    # The other participant of a one-to-one conversation, as seen by a user
    #
    # The sender, when the user did not send the message, and otherwise the other member of the
    # conversation, from the includes or as a stub holding only its identifier. A group conversation has no one
    # other participant.
    #
    # @api public
    # @param user [User, String, Integer] the user, usually the authenticated user, or their identifier
    # @return [User, nil] the other participant, or nil for a group conversation or one without another participant
    # @example Print who each message was exchanged with
    #   client.direct_messages.reject(&:group?).each { |message| puts message.peer(client.current_user!).username }
    def peer(user)
      return if group?
      return sender unless from?(user)

      user_id = Objects::Utils.id_of(user)
      resolve(User, dm_conversation_id.to_s.split("-").find { |id| !id.eql?(user_id) }) #: User?
    end

    # Delete this direct message event as the authenticated user
    #
    # @api public
    # @return [Boolean] true if the event was deleted
    # @example Delete a direct message
    #   message.delete
    def delete
      self.class.delete(self, client: client!)
    end

    attribute_alias :conversation_id, :dm_conversation_id
    attribute_alias :referenced_tweets, :referenced_posts
  end
end
