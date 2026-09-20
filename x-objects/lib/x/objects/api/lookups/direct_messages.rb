require_relative "../../direct_message"

module X
  module Objects
    module API
      module Lookups
        # Look up direct messages, and the conversations they belong to, mixed into a client through API
        # @api public
        module DirectMessages
          # Look up a direct message event by identifier
          #
          # @api public
          # @param id [String, Integer, DirectMessage] the identifier
          # @param params [Hash] query parameters merged over the default parameters
          # @return [DirectMessage, nil] the event or nil if the event was not found
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up a direct message
          #   client.find_direct_message(1234567890).text
          def find_direct_message(id, **params, &)
            DirectMessage.find(id, client: self, **params, &)
          end

          # Look up a direct message event by identifier, which must exist
          #
          # @api public
          # @param id [String, Integer, DirectMessage] the identifier
          # @param params [Hash] query parameters merged over the default parameters
          # @return [DirectMessage] the event
          # @raise [MissingResource] if the event was not found
          # @example Look up a direct message
          #   client.find_direct_message!(1234567890).text
          def find_direct_message!(id, **params)
            DirectMessage.find!(id, client: self, **params)
          end

          # The most recent direct message events across every conversation
          #
          # @api public
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Cursor] a cursor over the events
          # @example Print the most recent direct messages
          #   client.direct_messages.first(10).each { |message| puts message.text }
          def direct_messages(**params)
            DirectMessage.all(client: self, **params)
          end

          # The direct message events in the one-to-one conversation with a user
          #
          # @api public
          # @param user [User, String, Integer] the other participant or their identifier
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Cursor] a cursor over the events
          # @example Print the conversation with a user
          #   client.direct_messages_with(user).each { |message| puts message.text }
          def direct_messages_with(user, **params)
            DirectMessage.with(user, client: self, **params)
          end

          # The direct message events of a conversation, one-to-one or group
          #
          # @api public
          # @param conversation [DirectMessage, String, Integer] a message of the conversation, or the conversation's identifier
          # @param params [Hash] query parameters merged over the default parameters, such as event_types
          # @return [Cursor] a cursor over the events
          # @raise [ArgumentError] if the conversation identifier is not one
          # @example Print the conversation a message belongs to
          #   client.direct_messages_in(message).each { |event| puts event.text }
          def direct_messages_in(conversation, **params)
            DirectMessage.in(conversation, client: self, **params)
          end

          alias_method :find_dm, :find_direct_message
          alias_method :find_dm!, :find_direct_message!
          alias_method :dms, :direct_messages
          alias_method :dms_with, :direct_messages_with
          alias_method :dms_in, :direct_messages_in
        end
      end
    end
  end
end
