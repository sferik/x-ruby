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
      # @param text [String] the text of the first message
      # @param client [Object] the client used to make the request
      # @param params [Hash] additional fields of the message, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers, among them the new conversation's
      # @example Start a group conversation
      #   X::DirectMessage.create_group([alice, bob], "Hello, both of you!", client: client)
      def create_group(users, text, client:, **params)
        body = {conversation_type: "Group", participant_ids: users.map { |user| Utils.id_of(user) }, message: {text:, **params}}
        sent(client.post("dm_conversations", JSON.generate(body), **Utils::JSON_CLASSES), client:)
      end

      # Send a direct message to a conversation as the authenticated user
      #
      # @api public
      # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
      # @param text [String] the text of the message
      # @param client [Object] the client used to make the request
      # @param params [Hash] additional request body fields, such as attachments
      # @return [DirectMessage, nil] the sent message, holding only its identifiers
      # @raise [ArgumentError] if the conversation identifier is not one
      # @example Reply to the conversation of a message
      #   X::DirectMessage.create_in(message, "Sounds good", client: client)
      def create_in(conversation, text, client:, **params)
        path = "dm_conversations/#{conversation_id_of(conversation)}/messages"
        sent(client.post(path, JSON.generate({text:, **params}), **Utils::JSON_CLASSES), client:)
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
