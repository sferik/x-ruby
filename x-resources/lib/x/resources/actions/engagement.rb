# frozen_string_literal: true

require_relative "../post"
require_relative "../relation_writes"
require_relative "../utils"

module X
  module Resources
    module Actions
      # Like, repost, and bookmark posts as the authenticated user
      #
      # Internal to x-resources: X::Resources::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api semipublic
      module Engagement
        # Like a post as the authenticated user
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user now likes the post
        # @example Like a post
        #   client.like("1234567890")
        def like(post)
          RelationWrites.relate(self, current_user_id, "likes", {"tweet_id" => Utils.id_of(post, Post)}, "liked")
        end

        # Unlike a post as the authenticated user
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user no longer likes the post
        # @example Unlike a post
        #   client.unlike("1234567890")
        def unlike(post)
          RelationWrites.unrelate(self, current_user_id, "likes", Utils.id_of(post, Post), "liked")
        end

        # Repost a post as the authenticated user
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user has reposted the post
        # @example Repost a post
        #   client.repost("1234567890")
        def repost(post)
          RelationWrites.relate(self, current_user_id, "retweets", {"tweet_id" => Utils.id_of(post, Post)}, "retweeted")
        end

        # Undo a repost as the authenticated user
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user no longer reposts the post
        # @example Undo a repost
        #   client.unrepost("1234567890")
        def unrepost(post)
          RelationWrites.unrelate(self, current_user_id, "retweets", Utils.id_of(post, Post), "retweeted")
        end

        # Bookmark a post as the authenticated user
        #
        # Bookmarking a post takes only OAuth 2.0 user context, which the object layer cannot route around, so a
        # client that signs with OAuth 1.0a is refused.
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user has bookmarked the post
        # @example Bookmark a post
        #   client.bookmark("1234567890")
        def bookmark(post)
          RelationWrites.relate(self, current_user_id, "bookmarks", {"tweet_id" => Utils.id_of(post, Post)}, "bookmarked")
        end

        # Remove a bookmark as the authenticated user
        #
        # Removing a bookmark takes only OAuth 2.0 user context, which the object layer cannot route around, so a
        # client that signs with OAuth 1.0a is refused.
        #
        # @api public
        # @param post [Post, String, Integer] the post or its identifier
        # @return [Boolean] true if the authenticated user no longer has the post bookmarked
        # @example Remove a bookmark
        #   client.unbookmark("1234567890")
        def unbookmark(post)
          RelationWrites.unrelate(self, current_user_id, "bookmarks", Utils.id_of(post, Post), "bookmarked")
        end

        alias_method :retweet, :repost
        alias_method :unretweet, :unrepost
      end
    end
  end
end
