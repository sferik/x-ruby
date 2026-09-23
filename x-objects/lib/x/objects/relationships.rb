# frozen_string_literal: true

require "x/core/errors/forbidden"
require "x/core/errors/unauthorized"
require_relative "utils"

module X
  module Objects
    # Relationships with users, posts, and lists, changed as the authenticated user
    # @api public
    module Relationships
      # Follow a user, acting as this user, which must be the authenticated user
      #
      # A protected user must accept the request first, so following one reports true once the request is pending.
      #
      # @api public
      # @param user [Resource, String, Integer] the user to follow or their identifier
      # @return [Boolean] true if this user now follows the user, or has asked to follow a protected user
      # @example Follow a user
      #   client.current_user!.follow(client.find_user("sferik"))
      def follow(user)
        relate("following", "target_user_id", user, "following", "pending_follow")
      end

      # Unfollow a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to unfollow or their identifier
      # @return [Boolean] true if this user no longer follows the user
      # @example Unfollow a user
      #   client.current_user!.unfollow(client.find_user("sferik"))
      def unfollow(user)
        unrelate("following", user, "following")
      end

      # Block a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to block or their identifier
      # @return [Boolean] true if this user now blocks the user
      # @example Block a user
      #   client.current_user!.block(user)
      def block(user)
        relate("blocking", "target_user_id", user, "blocking")
      end

      # Unblock a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to unblock or their identifier
      # @return [Boolean] true if this user no longer blocks the user
      # @example Unblock a user
      #   client.current_user!.unblock(user)
      def unblock(user)
        unrelate("blocking", user, "blocking")
      end

      # Mute a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to mute or their identifier
      # @return [Boolean] true if this user now mutes the user
      # @example Mute a user
      #   client.current_user!.mute(user)
      def mute(user)
        relate("muting", "target_user_id", user, "muting")
      end

      # Unmute a user, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param user [Resource, String, Integer] the user to unmute or their identifier
      # @return [Boolean] true if this user no longer mutes the user
      # @example Unmute a user
      #   client.current_user!.unmute(user)
      def unmute(user)
        unrelate("muting", user, "muting")
      end

      # Like a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user now likes the post
      # @example Like a post
      #   client.current_user!.like(post)
      def like(post)
        relate("likes", "tweet_id", post, "liked")
      end

      # Unlike a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user no longer likes the post
      # @example Unlike a post
      #   client.current_user!.unlike(post)
      def unlike(post)
        unrelate("likes", post, "liked")
      end

      # Repost a post, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user has reposted the post
      # @example Repost a post
      #   client.current_user!.repost(post)
      def repost(post)
        relate("retweets", "tweet_id", post, "retweeted")
      end

      # Undo a repost, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user no longer reposts the post
      # @example Undo a repost
      #   client.current_user!.unrepost(post)
      def unrepost(post)
        unrelate("retweets", post, "retweeted")
      end

      # Bookmark a post, acting as this user, which must be the authenticated user
      #
      # The bookmark endpoints take only OAuth 2.0 user context, which the object layer cannot route around, so a
      # client that signs with OAuth 1.0a is refused.
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user has bookmarked the post
      # @example Bookmark a post
      #   client.current_user!.bookmark(post)
      def bookmark(post)
        relate("bookmarks", "tweet_id", post, "bookmarked")
      end

      # Remove a bookmark, acting as this user, which must be the authenticated user
      #
      # The bookmark endpoints take only OAuth 2.0 user context, which the object layer cannot route around, so a
      # client that signs with OAuth 1.0a is refused.
      #
      # @api public
      # @param post [Resource, String, Integer] the post or its identifier
      # @return [Boolean] true if this user no longer has the post bookmarked
      # @example Remove a bookmark
      #   client.current_user!.unbookmark(post)
      def unbookmark(post)
        unrelate("bookmarks", post, "bookmarked")
      end

      # Follow a list, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param list [Resource, String, Integer] the list or its identifier
      # @return [Boolean] true if this user now follows the list
      # @example Follow a list
      #   client.current_user!.follow_list(list)
      def follow_list(list)
        relate("followed_lists", "list_id", list, "following")
      end

      # Unfollow a list, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param list [Resource, String, Integer] the list or its identifier
      # @return [Boolean] true if this user no longer follows the list
      # @example Unfollow a list
      #   client.current_user!.unfollow_list(list)
      def unfollow_list(list)
        unrelate("followed_lists", list, "following")
      end

      # Pin a list, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param list [Resource, String, Integer] the list or its identifier
      # @return [Boolean] true if this user has pinned the list
      # @example Pin a list
      #   client.current_user!.pin_list(list)
      def pin_list(list)
        relate("pinned_lists", "list_id", list, "pinned")
      end

      # Unpin a list, acting as this user, which must be the authenticated user
      #
      # @api public
      # @param list [Resource, String, Integer] the list or its identifier
      # @return [Boolean] true if this user no longer has the list pinned
      # @example Unpin a list
      #   client.current_user!.unpin_list(list)
      def unpin_list(list)
        unrelate("pinned_lists", list, "pinned")
      end

      # Check whether this user follows a user
      #
      # When either user is the authenticated user, one lookup of the other's connection_status answers.
      # Otherwise the users this user follows are scanned until one matches, up to 1,000 a page, and the
      # API bills every user returned, so checking an account that follows thousands can cost dollars. A client
      # that authenticates as the app alone has no authenticated user, which the API refuses to look up, so it scans.
      # Any other failure to look the authenticated user up raises, rather than scan every user this one follows.
      #
      # @api public
      # @param user [User, String, Integer] the user or their identifier
      # @return [Boolean] true if this user follows the user
      # @example Check whether the authenticated user follows someone, in one lookup
      #   client.current_user!.follows?(other)
      def follows?(user)
        target = User.from_id(user)
        case authenticated_user_id
        when id then connection_status_of(target).include?("following")
        when target.id then connection_status_of(self).include?("followed_by")
        else following.stubs.include?(target)
        end
      end

      alias_method :retweet, :repost
      alias_method :unretweet, :unrepost

      private

      # The identifier of the authenticated user, when the client knows it
      #
      # A client that authenticates as the app alone has no authenticated user, and asks the API for one in vain,
      # so the refusal of the credentials of the client leaves the identifier unknown rather than end the check. Any
      # other error, such as a rate limit, a failure of the API, or of the network, ends it, since a scan in its place
      # would page through every user this one follows, which the API bills.
      #
      # @api private
      # @return [Integer, nil] the identifier, or nil if the client has no current_user_id or cannot read one
      # @raise [X::Error] if the API fails to answer for another reason than the credentials of the client
      def authenticated_user_id
        current = client! #: untyped
        current.current_user_id if current.respond_to?(:current_user_id)
      rescue X::Forbidden, X::Unauthorized
        nil
      end

      # How the authenticated user is connected to a user, in one lookup
      # @api private
      # @param user [User, String, Integer] the user or their identifier
      # @return [Array<String>] the connection statuses, empty if the user was not found
      def connection_status_of(user)
        found = User.find(user, client: client!, "user.fields": "connection_status", "post.fields": nil, expansions: nil)
        Array(found&.connection_status)
      end

      # Relate a resource to this user and report the resulting state
      # @api private
      # @param relation [String] the relation endpoint, such as following, likes, or pinned_lists
      # @param key [String] the request body field holding the identifier of the target
      # @param target [Resource, String, Integer] the related resource or its identifier
      # @param states [Array<String>] the response fields reporting the state, any of which is true once it exists
      # @return [Boolean] true if the relation now exists
      def relate(relation, key, target, *states)
        body = client!.post("users/#{id}/#{relation}", {key => Utils.id_of(target)}, **Utils::JSON_CLASSES)
        states.any? { |state| body.to_h.dig("data", state).eql?(true) }
      end

      # Remove a relation from this user and report the resulting state
      # @api private
      # @param relation [String] the relation endpoint, such as following, likes, or pinned_lists
      # @param target [Resource, String, Integer] the related resource or its identifier
      # @param state [String] the response field reporting the state
      # @return [Boolean] true if the relation no longer exists
      def unrelate(relation, target, state)
        body = client!.delete("users/#{id}/#{relation}/#{Utils.id_of(target)}", **Utils::JSON_CLASSES)
        body.to_h.dig("data", state).eql?(false)
      end
    end
  end
end
