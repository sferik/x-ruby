require "json"
require_relative "utils"

module X
  module Objects
    # Actions taken as a user, which must be the authenticated user
    # @api public
    module Actions
      # Follow a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to follow or their identifier
      # @return [Boolean] true if this user now follows the user
      # @example Follow a user
      #   client.me.follow(client.user("sferik"))
      def follow(user)
        body = client!.post("users/#{id}/following", JSON.generate({target_user_id: Utils.id_of(user)}),
          **Utils::JSON_CLASSES)
        body.to_h.dig("data", "following").eql?(true)
      end

      # Unfollow a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to unfollow or their identifier
      # @return [Boolean] true if this user no longer follows the user
      # @example Unfollow a user
      #   client.me.unfollow(client.user("sferik"))
      def unfollow(user)
        destroy("following", user, "following")
      end

      # Like a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user now likes the post
      # @example Like a post
      #   client.me.like(post)
      def like(post)
        create("likes", post, "liked")
      end

      # Unlike a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user no longer likes the post
      # @example Unlike a post
      #   client.me.unlike(post)
      def unlike(post)
        destroy("likes", post, "liked")
      end

      # Repost a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user has reposted the post
      # @example Repost a post
      #   client.me.repost(post)
      def repost(post)
        create("retweets", post, "retweeted")
      end

      # Undo a repost, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user no longer reposts the post
      # @example Undo a repost
      #   client.me.unrepost(post)
      def unrepost(post)
        destroy("retweets", post, "retweeted")
      end

      alias_method :retweet, :repost
      alias_method :unretweet, :unrepost

      private

      # Relate a post to this user and report the resulting state
      # @api private
      # @param relation [String] the relation endpoint: likes or retweets
      # @param post [Resource, String, Integer] the post or its identifier
      # @param state [String] the response field reporting the state
      # @return [Boolean] true if the relation now exists
      def create(relation, post, state)
        body = client!.post("users/#{id}/#{relation}", JSON.generate({tweet_id: Utils.id_of(post)}),
          **Utils::JSON_CLASSES)
        body.to_h.dig("data", state).eql?(true)
      end

      # Remove a relation from this user and report the resulting state
      # @api private
      # @param relation [String] the relation endpoint: following, likes, or retweets
      # @param target [Resource, String, Integer] the related resource or its identifier
      # @param state [String] the response field reporting the state
      # @return [Boolean] true if the relation no longer exists
      def destroy(relation, target, state)
        body = client!.delete("users/#{id}/#{relation}/#{Utils.id_of(target)}", **Utils::JSON_CLASSES)
        body.to_h.dig("data", state).eql?(false)
      end
    end
  end
end
