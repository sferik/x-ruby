# frozen_string_literal: true

require_relative "../../user"

module X
  module Objects
    module API
      module Actions
        # Follow, block, and mute users as the authenticated user
        # @api public
        module Relationships
          # Follow a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user now follows the user, or has asked to follow a protected user
          # @example Follow a user
          #   client.follow("7505382")
          def follow(user)
            User.from_id(current_user_id, client: self).follow(user)
          end

          # Unfollow a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user no longer follows the user
          # @example Unfollow a user
          #   client.unfollow("7505382")
          def unfollow(user)
            User.from_id(current_user_id, client: self).unfollow(user)
          end

          # Block a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user now blocks the user
          # @example Block a user
          #   client.block("7505382")
          def block(user)
            User.from_id(current_user_id, client: self).block(user)
          end

          # Unblock a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user no longer blocks the user
          # @example Unblock a user
          #   client.unblock("7505382")
          def unblock(user)
            User.from_id(current_user_id, client: self).unblock(user)
          end

          # Mute a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user now mutes the user
          # @example Mute a user
          #   client.mute("7505382")
          def mute(user)
            User.from_id(current_user_id, client: self).mute(user)
          end

          # Unmute a user as the authenticated user
          #
          # @api public
          # @param user [User, String, Integer] the user or their identifier
          # @return [Boolean] true if the authenticated user no longer mutes the user
          # @example Unmute a user
          #   client.unmute("7505382")
          def unmute(user)
            User.from_id(current_user_id, client: self).unmute(user)
          end
        end
      end
    end
  end
end
