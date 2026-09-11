module X
  module Objects
    # Resolves the posts referenced by a post through its referenced_tweets attribute
    # @api public
    module ReferencedPosts
      # Referenced post type for replies
      REPLIED_TO = "replied_to".freeze
      # Referenced post type for quotes
      QUOTED = "quoted".freeze
      # Referenced post type for reposts
      RETWEETED = "retweeted".freeze

      # The referenced posts, resolved from the includes or built as stubs
      #
      # @api public
      # @return [Array<Post>] the referenced posts
      # @example Get the referenced posts
      #   post.referenced_posts
      def referenced_posts
        Array(referenced_tweets).filter_map do |reference|
          resolve(Post, reference["id"]) #: Post?
        end.freeze
      end

      # The post this post replies to
      #
      # @api public
      # @return [Post, nil] the replied-to post
      # @example Get the replied-to post
      #   post.replied_to
      def replied_to
        referenced_post(REPLIED_TO)
      end

      # The post this post quotes
      #
      # @api public
      # @return [Post, nil] the quoted post
      # @example Get the quoted post
      #   post.quoted
      def quoted
        referenced_post(QUOTED)
      end

      # The post this post reposts
      #
      # @api public
      # @return [Post, nil] the reposted post
      # @example Get the reposted post
      #   post.reposted
      def reposted
        referenced_post(RETWEETED)
      end

      # Check whether this post is a reply
      #
      # @api public
      # @return [Boolean] true if the post replies to another post
      # @example Check whether a post is a reply
      #   post.reply?
      def reply?
        !replied_to.nil?
      end

      # Check whether this post is a quote
      #
      # @api public
      # @return [Boolean] true if the post quotes another post
      # @example Check whether a post is a quote
      #   post.quote?
      def quote?
        !quoted.nil?
      end

      # Check whether this post is a repost
      #
      # @api public
      # @return [Boolean] true if the post reposts another post
      # @example Check whether a post is a repost
      #   post.repost?
      def repost?
        !reposted.nil?
      end

      alias_method :retweeted, :reposted
      alias_method :retweet?, :repost?

      private

      # Resolve the first referenced post of a type
      # @api private
      # @param type [String] the referenced post type
      # @return [Post, nil] the referenced post or nil if there is none of that type
      def referenced_post(type)
        reference = Array(referenced_tweets).find { |element| element["type"].eql?(type) }
        return if reference.nil?

        resolve(Post, reference["id"]) #: Post?
      end
    end
  end
end
