module X
  module Objects
    # Resolves the posts a post refers to through its referenced_posts attribute
    # @api public
    module References
      # Referenced post type for replies
      REPLIED_TO = "replied_to".freeze
      # Referenced post type for quotes
      QUOTED = "quoted".freeze
      # Referenced post type for reposts, as the API labels them
      REPOSTED = "reposted".freeze
      # Referenced post type for reposts, as the API documentation labels them
      RETWEETED = "retweeted".freeze

      # The referenced posts, resolved from the includes or built as stubs
      #
      # @api public
      # @return [Array<Post>] the referenced posts
      # @example Get the referenced posts
      #   post.references
      def references
        Array(referenced_posts).filter_map do |reference|
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
        reference(REPLIED_TO)
      end

      # The post this post quotes
      #
      # @api public
      # @return [Post, nil] the quoted post
      # @example Get the quoted post
      #   post.quoted
      def quoted
        reference(QUOTED)
      end

      # The post this post reposts
      #
      # @api public
      # @return [Post, nil] the reposted post
      # @example Get the reposted post
      #   post.reposted
      def reposted
        reference(REPOSTED, RETWEETED)
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

      # Resolve the first referenced post of any of some types
      # @api private
      # @param types [Array<String>] the referenced post types
      # @return [Post, nil] the referenced post or nil if there is none of those types
      def reference(*types)
        found = Array(referenced_posts).find { |element| types.include?(element["type"]) }
        return if found.nil?

        resolve(Post, found["id"]) #: Post?
      end
    end
  end
end
