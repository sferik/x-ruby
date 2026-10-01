# frozen_string_literal: true

require_relative "../user"

module X
  module Objects
    module Actions
      # Follow, block, and mute users as the authenticated user
      #
      # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api private
      module Relationships
        # Follow a user as the authenticated user
        #
        # A protected user must accept a request to follow them first, so for a protected user true means the follow
        # was requested, not that the authenticated user follows them: until they accept it, the follows? of the
        # authenticated user, as in client.current_user!.follows?(user), answers false.
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user now follows the user, or, for a protected user, has requested
        #   to follow them
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
