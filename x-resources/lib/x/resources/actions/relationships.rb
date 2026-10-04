# frozen_string_literal: true

require_relative "../relation_writes"
require_relative "../user"
require_relative "../utils"

module X
  module Resources
    module Actions
      # Follow, block, and mute users as the authenticated user
      #
      # Internal to x-resources: X::Resources::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api semipublic
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
          RelationWrites.relate(self, current_user_id, "following", {"target_user_id" => Utils.id_of(user, User)}, "following", "pending_follow")
        end

        # Unfollow a user as the authenticated user
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user no longer follows the user
        # @example Unfollow a user
        #   client.unfollow("7505382")
        def unfollow(user)
          RelationWrites.unrelate(self, current_user_id, "following", Utils.id_of(user, User), "following")
        end

        # Block a user as the authenticated user
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user now blocks the user
        # @example Block a user
        #   client.block("7505382")
        def block(user)
          RelationWrites.relate(self, current_user_id, "blocking", {"target_user_id" => Utils.id_of(user, User)}, "blocking")
        end

        # Unblock a user as the authenticated user
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user no longer blocks the user
        # @example Unblock a user
        #   client.unblock("7505382")
        def unblock(user)
          RelationWrites.unrelate(self, current_user_id, "blocking", Utils.id_of(user, User), "blocking")
        end

        # Mute a user as the authenticated user
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user now mutes the user
        # @example Mute a user
        #   client.mute("7505382")
        def mute(user)
          RelationWrites.relate(self, current_user_id, "muting", {"target_user_id" => Utils.id_of(user, User)}, "muting")
        end

        # Unmute a user as the authenticated user
        #
        # @api public
        # @param user [User, String, Integer] the user or their identifier
        # @return [Boolean] true if the authenticated user no longer mutes the user
        # @example Unmute a user
        #   client.unmute("7505382")
        def unmute(user)
          RelationWrites.unrelate(self, current_user_id, "muting", Utils.id_of(user, User), "muting")
        end
      end
    end
  end
end
