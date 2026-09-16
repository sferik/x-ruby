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
          # @param text [String] the text of the message
          # @param params [Hash] additional request body fields, such as attachments
          # @return [DirectMessage, nil] the sent message, holding only its identifiers
          # @example Send a direct message
          #   client.create_direct_message(user, "Hello!")
          def create_direct_message(user, text, **params)
            DirectMessage.create(user, text, client: self, **params)
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
          alias_method :delete_dm, :delete_direct_message
        end
      end
    end
  end
end
