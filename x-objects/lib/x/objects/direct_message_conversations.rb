require "json"
require_relative "cursor"
require_relative "utils"

module X
  module Objects
    # Group conversations of direct messages: starting one, sending to one, and reading one, extended by DirectMessage
    # @api public
    module DirectMessageConversations
      # The pattern of a conversation identifier: two user identifiers joined with a hyphen, or a group's own number
      CONVERSATION_ID = /\A\d+(-\d+)?\z/

      # Start a group conversation, sending its first message as the authenticated user
      #
      # @api public
      # @param users [Array<User, String, Integer>] the other participants or their identifiers
      # @param text [String, nil] the text of the first message, or nil for a message of attachments alone
      # @param client [Object] the client used to make the request
      # @param media_ids [Array<String, Integer, #fetch>, String, Integer, #fetch, nil] the identifiers of uploaded
      #   media to attach, or what the uploads returned, one or many
      # @param params [Hash] additional fields of the message, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers, among them the new conversation's
      # @raise [ArgumentError] if the message has neither text nor any other field, or has both media_ids and
      #   attachments
      # @example Start a group conversation
      #   X::DirectMessage.create_group([alice, bob], "Hello, both of you!", client: client)
      # @example Start a group conversation with an image
      #   X::DirectMessage.create_group([alice, bob], client: client, media_ids: media)
      def create_group(users, text = nil, client:, media_ids: nil, **params)
        body = {conversation_type: "Group", participant_ids: users.map { |user| Utils.id_of(user) }, message: message(text, params, media_ids)}
        sent(client.post("dm_conversations", JSON.generate(body), **Utils::JSON_CLASSES), client:)
      end

      # Send a direct message to a conversation as the authenticated user
      #
      # @api public
      # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
      # @param text [String, nil] the text of the message, or nil for a message of attachments alone
      # @param client [Object] the client used to make the request
      # @param media_ids [Array<String, Integer, #fetch>, String, Integer, #fetch, nil] the identifiers of uploaded
      #   media to attach, or what the uploads returned, one or many
      # @param params [Hash] additional request body fields, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers
      # @raise [ArgumentError] if the conversation identifier is not one, the message has neither text nor any other
      #   field, or it has both media_ids and attachments
      # @example Reply to the conversation of a message
      #   X::DirectMessage.create_in(message, "Sounds good", client: client)
      # @example Reply with an image
      #   X::DirectMessage.create_in(message, client: client, media_ids: media)
      def create_in(conversation, text = nil, client:, media_ids: nil, **params)
        path = "dm_conversations/#{conversation_id_of(conversation)}/messages"
        sent(client.post(path, JSON.generate(message(text, params, media_ids)), **Utils::JSON_CLASSES), client:)
      end

      # The direct message events of a conversation, one-to-one or group
      #
      # @api public
      # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters, such as event_types
      # @return [Cursor] a cursor over the events
      # @raise [ArgumentError] if the conversation identifier is not one
      # @example Print the conversation a message belongs to
      #   X::DirectMessage.in(message, client: client).each { |event| puts event.text }
      def in(conversation, client:, **params)
        path = "dm_conversations/#{conversation_id_of(conversation)}/dm_events"
        Cursor.new(DirectMessage, path, client:, params: {max_results: DirectMessage::MAX_RESULTS}.merge(params))
      end

      private

      # The identifier of a conversation, from a message of it or as given
      # @api private
      # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
      # @return [String] the conversation identifier
      # @raise [ArgumentError] if the identifier is not one
      def conversation_id_of(conversation)
        id = case conversation
        when DirectMessage then conversation.dm_conversation_id.to_s
        else conversation.to_s
        end
        return id if id.match?(CONVERSATION_ID)

        raise ArgumentError, "#{conversation.inspect} is not a conversation: pass a direct message or a conversation identifier"
      end

      # The fields of a message to send, which needs text or attachments
      #
      # The API takes media as attachments, each an object holding the identifier of one upload as a String, so
      # media_ids builds them, and a caller who builds them itself passes attachments instead.
      #
      # @api private
      # @param text [String, nil] the text of the message
      # @param params [Hash] additional fields of the message, such as attachments
      # @param media_ids [Array, #fetch, String, Integer, nil] the identifiers of uploaded media to attach, or what
      #   the uploads returned, one or many; an empty list attaches nothing, as nil does
      # @return [Hash{Symbol => Object}] the fields, without the text when there is none
      # @raise [ArgumentError] if the message has neither text nor any other field, or has both media_ids and
      #   attachments
      def message(text, params, media_ids)
        raise ArgumentError, "pass media_ids or attachments, not both" if !media_ids.nil? && params.key?(:attachments)

        fields = {text:, **params}.compact
        attachments = Utils.media_ids_of(media_ids).map { |media_id| {media_id:} }
        fields[:attachments] = attachments unless attachments.empty?
        raise ArgumentError, "a direct message needs text, or something else to show, such as media_ids" if fields.empty?

        fields
      end

      # The message a send created, from the identifiers the API returned
      # @api private
      # @param body [Hash, nil] the response body
      # @param client [Object] the client used to make the request
      # @return [DirectMessage, nil] the message, or nil if the response holds no data
      def sent(body, client:)
        data = body.to_h["data"]
        return unless data.is_a?(Hash)

        new({"id" => data["dm_event_id"], "dm_conversation_id" => data["dm_conversation_id"]}, client:)
      end
    end
  end
end
