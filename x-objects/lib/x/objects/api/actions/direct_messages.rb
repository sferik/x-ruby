# frozen_string_literal: true

require_relative "../../direct_message"

module X
  module Objects
    module API
      module Actions
        # Send and delete direct messages as the authenticated user
        # @api public
        module DirectMessages
          # Send a direct message to a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the recipient or their identifier
          # @param text [String, nil] the text of the message, or nil for a message of attachments alone
          # @param params [Hash] additional request body fields, such as media_ids or attachments
          # @option params [Array<String, Integer, #fetch>, String, Integer, #fetch] :media_ids the identifiers of
          #   uploaded media to attach, or what the uploads returned, one or many
          # @return [DirectMessage, nil] the sent message, holding only its identifiers
          # @raise [ArgumentError] if the message has neither text nor any other field, or has both media_ids and
          #   attachments
          # @example Send a direct message
          #   client.create_direct_message(user, "Hello!")
          # @example Send an image without text
          #   client.create_direct_message(user, media_ids: media)
          def create_direct_message(user, text = nil, **params)
            DirectMessage.create(user, text, client: self, **params)
          end

          # Start a group conversation, sending its first message as the authenticated user
          #
          # @api public
          # @param users [Array<User, String, Integer>] the other participants or their identifiers
          # @param text [String, nil] the text of the first message, or nil for a message of attachments alone
          # @param params [Hash] additional fields of the message, such as media_ids or attachments
          # @option params [Array<String, Integer, #fetch>, String, Integer, #fetch] :media_ids the identifiers of
          #   uploaded media to attach, or what the uploads returned, one or many
          # @return [DirectMessage, nil] the sent message, holding only its identifiers, among them the conversation's
          # @raise [ArgumentError] if the message has neither text nor any other field, or has both media_ids and
          #   attachments
          # @example Start a group conversation
          #   client.create_group_direct_message([alice, bob], "Hello, both of you!")
          # @example Start a group conversation with an image
          #   client.create_group_direct_message([alice, bob], media_ids: media)
          def create_group_direct_message(users, text = nil, **params)
            DirectMessage.create_group(users, text, client: self, **params)
          end

          # Send a direct message to a conversation as the authenticated user
          #
          # The conversation can be one-to-one or a group.
          #
          # @api public
          # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
          # @param text [String, nil] the text of the message, or nil for a message of attachments alone
          # @param params [Hash] additional request body fields, such as media_ids or attachments
          # @option params [Array<String, Integer, #fetch>, String, Integer, #fetch] :media_ids the identifiers of
          #   uploaded media to attach, or what the uploads returned, one or many
          # @return [DirectMessage, nil] the sent message, holding only its identifiers
          # @raise [ArgumentError] if the conversation identifier is not one, the message has neither text nor any
          #   other field, or it has both media_ids and attachments
          # @example Reply to the conversation of a message
          #   client.create_direct_message_in(message, "Sounds good")
          # @example Reply with an image
          #   client.create_direct_message_in(message, media_ids: media)
          def create_direct_message_in(conversation, text = nil, **params)
            DirectMessage.create_in(conversation, text, client: self, **params)
          end

          # Delete a direct message event as the authenticated user
          #
          # @api public
          # @param message [DirectMessage, String, Integer] the event or its identifier
          # @return [Boolean] true if the event was deleted
          # @example Delete a direct message
          #   client.delete_direct_message("1234567890")
          def delete_direct_message(message)
            DirectMessage.delete(message, client: self)
          end

          alias_method :create_dm, :create_direct_message
          alias_method :create_group_dm, :create_group_direct_message
          alias_method :create_dm_in, :create_direct_message_in
          alias_method :delete_dm, :delete_direct_message
        end
      end
    end
  end
end
