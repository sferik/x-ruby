# frozen_string_literal: true

require_relative "../../list"
require_relative "../../user"

module X
  module Objects
    module API
      module Actions
        # Create, update, delete, follow, and pin lists as the authenticated user
        # @api public
        module Lists
          # Create a list owned by the authenticated user
          #
          # @api public
          # @param name [String] the name of the list
          # @param params [Hash] additional request body fields: description and private
          # @return [List, nil] the created list, holding only its identifier and name
          # @example Create a private list
          #   client.create_list("Rubyists", private: true)
          def create_list(name, **params)
            List.create(name, client: self, **params)
          end

          # Update the name, description, or privacy of a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @param params [Hash] the request body fields to change: name, description, and private
          # @return [Boolean] true if the list was updated
          # @example Make a list private
          #   client.update_list("1234567890", private: true)
          def update_list(list, **params)
            List.update(list, client: self, **params)
          end

          # Delete a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the list was deleted
          # @example Delete a list
          #   client.delete_list("1234567890")
          def delete_list(list)
            List.delete(list, client: self)
          end

          # Add a member to a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the user is now a member
          # @example Add a member to a list
          #   client.add_list_member("1234567890", user)
          def add_list_member(list, user)
            List.from_id(list, client: self).add_member(user)
          end

          # Remove a member from a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the user is no longer a member
          # @example Remove a member from a list
          #   client.remove_list_member("1234567890", user)
          def remove_list_member(list, user)
            List.from_id(list, client: self).remove_member(user)
          end

          # Follow a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the authenticated user now follows the list
          # @example Follow a list
          #   client.follow_list("1234567890")
          def follow_list(list)
            User.from_id(current_user_id, client: self).follow_list(list)
          end

          # Unfollow a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the authenticated user no longer follows the list
          # @example Unfollow a list
          #   client.unfollow_list("1234567890")
          def unfollow_list(list)
            User.from_id(current_user_id, client: self).unfollow_list(list)
          end

          # Pin a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the authenticated user has pinned the list
          # @example Pin a list
          #   client.pin_list("1234567890")
          def pin_list(list)
            User.from_id(current_user_id, client: self).pin_list(list)
          end

          # Unpin a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the authenticated user no longer has the list pinned
          # @example Unpin a list
          #   client.unpin_list("1234567890")
          def unpin_list(list)
            User.from_id(current_user_id, client: self).unpin_list(list)
          end
        end
      end
    end
  end
end
