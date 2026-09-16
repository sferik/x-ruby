require_relative "../../user"

module X
  module Objects
    module API
      module Actions
        # Like and repost posts as the authenticated user
        # @api public
        module Engagement
          # Like a post as the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the post or its identifier
          # @return [Boolean] true if the authenticated user now likes the post
          # @example Like a post
          #   client.like("1234567890")
          def like(post)
            User.from_id(current_user_id, client: self).like(post)
          end

          # Unlike a post as the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the post or its identifier
          # @return [Boolean] true if the authenticated user no longer likes the post
          # @example Unlike a post
          #   client.unlike("1234567890")
          def unlike(post)
            User.from_id(current_user_id, client: self).unlike(post)
          end

          # Repost a post as the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the post or its identifier
          # @return [Boolean] true if the authenticated user has reposted the post
          # @example Repost a post
          #   client.repost("1234567890")
          def repost(post)
            User.from_id(current_user_id, client: self).repost(post)
          end

          # Undo a repost as the authenticated user
          #
          # @api public
          # @param post [Post, String, Integer] the post or its identifier
          # @return [Boolean] true if the authenticated user no longer reposts the post
          # @example Undo a repost
          #   client.unrepost("1234567890")
          def unrepost(post)
            User.from_id(current_user_id, client: self).unrepost(post)
          end

          alias_method :retweet, :repost
          alias_method :unretweet, :unrepost
        end
      end
    end
  end
end
