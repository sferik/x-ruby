# frozen_string_literal: true

module X
  module Objects
    # The collections of a post: the users who liked and reposted it, and its reposts and quotes, included into Post
    #
    # Internal to x-objects: the methods it gives a post, such as liked_by, are public API, but the module is only how
    # they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module PostCollections
      # Maximum number of users or posts per page
      MAX_RESULTS = 100
      private_constant :MAX_RESULTS

      # The users who liked this post
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the users who liked the post
      # @example Print the users who liked a post
      #   post.liked_by.each { |user| puts user.username }
      def liked_by(**params)
        cursor(User, "tweets/#{id}/liking_users", max_results: MAX_RESULTS, **params)
      end

      # The users who reposted this post
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the reposting users
      # @example Print the reposting users
      #   post.reposted_by.each { |user| puts user.username }
      def reposted_by(**params)
        cursor(User, "tweets/#{id}/retweeted_by", max_results: MAX_RESULTS, **params)
      end

      # The reposts of this post, each a post of its own by the user who reposted it
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the reposts
      # @example Print when and by whom a post was reposted
      #   post.reposts.each { |repost| puts "#{repost.author.username} at #{repost.created_at}" }
      def reposts(**params)
        cursor(Post, "tweets/#{id}/retweets", max_results: MAX_RESULTS, **params)
      end

      # The posts quoting this post
      #
      # @api public
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the quotes
      # @example Print the quotes
      #   post.quotes.each { |quote| puts quote.text }
      def quotes(**params)
        cursor(Post, "tweets/#{id}/quote_tweets", max_results: MAX_RESULTS, min_results: 10, **params)
      end

      alias_method :retweeted_by, :reposted_by
      alias_method :retweets, :reposts
      alias_method :quote_tweets, :quotes
    end
    private_constant :PostCollections
  end
end
