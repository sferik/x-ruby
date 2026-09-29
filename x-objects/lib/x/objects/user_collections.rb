# frozen_string_literal: true

require_relative "bookmark_folder"
require_relative "utils"

module X
  module Objects
    # The collections of a user: the users they follow and are followed by, their posts, timelines, bookmarks, and
    # lists, included into User
    #
    # Internal to x-objects: the methods it gives a user, such as followers, are public API, but the module is only how
    # they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module UserCollections
      # The users following this user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the followers
      # @example Print every follower
      #   user.followers.each { |follower| puts follower.username }
      def followers(**params)
        cursor(User, "users/#{id}/followers", max_results: User::MAX_FOLLOW_RESULTS, total: :followers_count, **params)
      end

      # The users this user follows
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the followed users
      # @example Count the followed users
      #   user.following.count
      def following(**params)
        cursor(User, "users/#{id}/following", max_results: User::MAX_FOLLOW_RESULTS, total: :following_count, **params)
      end

      # The users affiliated with this user, such as the people of an organization
      #
      # They are the accounts whose affiliation names this user, which affiliated_users reads of each of them.
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the affiliated users
      # @example Print the users affiliated with an organization
      #   client.find_user!("X").affiliates.each { |user| puts user.username }
      def affiliates(**params) = cursor(User, "users/#{id}/affiliates", max_results: User::MAX_FOLLOW_RESULTS, **params)

      # The users this user blocks, which must be the authenticated user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the blocked users
      # @example Print every blocked user
      #   client.current_user!.blocking.each { |user| puts user.username }
      def blocking(**params)
        cursor(User, "users/#{id}/blocking", max_results: User::MAX_FOLLOW_RESULTS, **params)
      end

      # The users this user mutes, which must be the authenticated user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the muted users
      # @example Print every muted user
      #   client.current_user!.muting.each { |user| puts user.username }
      def muting(**params)
        cursor(User, "users/#{id}/muting", max_results: User::MAX_FOLLOW_RESULTS, **params)
      end

      # The posts by this user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the posts
      # @example Print the most recent posts
      #   user.posts.first(10).each { |post| puts post.text }
      def posts(**params)
        cursor(Post, "users/#{id}/tweets", max_results: User::MAX_RESULTS, min_results: 5, **params)
      end

      # The home timeline of this user, which must be the authenticated user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the posts by the users this user follows, newest first
      # @example Print the home timeline
      #   client.current_user!.home_timeline.first(10).each { |post| puts post.text }
      def home_timeline(**params)
        cursor(Post, "users/#{id}/timelines/reverse_chronological", max_results: User::MAX_RESULTS, **params)
      end

      # The posts mentioning this user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the mentions
      # @example Print the most recent mentions
      #   user.mentions.first(10).each { |post| puts post.text }
      def mentions(**params)
        cursor(Post, "users/#{id}/mentions", max_results: User::MAX_RESULTS, min_results: 5, **params)
      end

      # The posts liked by this user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the liked posts
      # @example Print the most recently liked posts
      #   user.liked_posts.first(10).each { |post| puts post.text }
      def liked_posts(**params)
        cursor(Post, "users/#{id}/liked_tweets", max_results: User::MAX_RESULTS, min_results: 5, **params)
      end

      # The posts bookmarked by the authenticated user, or those of one of their folders
      #
      # The API gives the posts of a folder by their identifiers alone, and takes no fields for them, so they are
      # stubs, which hydrate together, a lookup's worth at a time, as the stubs of any cursor do.
      #
      # The bookmark endpoints take only the authentication of a user, and the bookmarks themselves only OAuth 2.0 user
      # context, which the object layer cannot route around, so a client that signs with OAuth 1.0a is refused them.
      #
      # @api public
      # @param folder [BookmarkFolder, String, Integer, nil] the folder or its identifier, or nil for every bookmark
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the bookmarked posts
      # @raise [ArgumentError] if the folder is not a folder or the identifier of one, before a request
      # @example Print the bookmarked posts
      #   client.current_user!.bookmarks.each { |post| puts post.text }
      # @example Print the posts of the first bookmark folder
      #   user = client.current_user!
      #   user.bookmarks(folder: user.bookmark_folders.first).each { |post| puts post.hydrate.text }
      def bookmarks(folder: nil, **params)
        return cursor(Post, "users/#{id}/bookmarks", max_results: User::MAX_RESULTS, **params) if folder.nil?

        cursor(Post, "users/#{id}/bookmarks/folders/#{Utils.id_of(folder, BookmarkFolder)}", max_results: User::MAX_RESULTS, ids_only: true, **params)
      end

      # The bookmark folders of the authenticated user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the folders
      # @example Print the names of the bookmark folders
      #   client.current_user!.bookmark_folders.each { |folder| puts folder.name }
      def bookmark_folders(**params)
        cursor(BookmarkFolder, "users/#{id}/bookmarks/folders", max_results: User::MAX_RESULTS, **params)
      end

      # The lists owned by this user
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the owned lists
      # @example Print the owned lists
      #   user.owned_lists.each { |list| puts list.name }
      def owned_lists(**params)
        cursor(List, "users/#{id}/owned_lists", max_results: User::MAX_RESULTS, **params)
      end

      # The lists this user is a member of
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the list memberships
      # @example Print the list memberships
      #   user.list_memberships.each { |list| puts list.name }
      def list_memberships(**params)
        cursor(List, "users/#{id}/list_memberships", max_results: User::MAX_RESULTS, total: :listed_count, **params)
      end

      # The lists this user follows
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the followed lists
      # @example Print the followed lists
      #   user.followed_lists.each { |list| puts list.name }
      def followed_lists(**params)
        cursor(List, "users/#{id}/followed_lists", max_results: User::MAX_RESULTS, **params)
      end

      # The lists this user has pinned
      #
      # The API returns them in one response, without pages.
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the pinned lists
      # @example Print the pinned lists
      #   client.current_user!.pinned_lists.each { |list| puts list.name }
      def pinned_lists(**params)
        cursor(List, "users/#{id}/pinned_lists", max_results: nil, **params)
      end

      alias_method :tweets, :posts
      alias_method :liked_tweets, :liked_posts
    end
  end
end
