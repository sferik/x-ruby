# frozen_string_literal: true

require_relative "cursor"
require_relative "utils"

module X
  module Objects
    # The searches of posts, and the posts of the authenticated user that others reposted
    #
    # Internal to x-objects: the methods it gives Post, such as X::Post.search, are public API, but the module is only
    # how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module PostSearch
      # Search recent posts
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print posts about Ruby
      #   X::Post.search("ruby -is:retweet", client: client).each { |post| puts post.text }
      def search(query, client:, **params)
        # @type self: singleton(Post)
        Cursor.__send__(:build, self, "tweets/search/recent", client:, params: {query:, max_results: Post::MAX_RESULTS}.merge(params), min_results: 10)
      end

      # Search the full archive of posts
      #
      # A page holds up to 500 posts, or 100 when the request asks for context annotations, as the default fields do.
      #
      # @api public
      # @param query [String] the search query
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the matching posts
      # @example Print every post about Ruby
      #   X::Post.search_all("ruby -is:retweet", client: client).each { |post| puts post.text }
      # @example Page through every post about Ruby 500 at a time, without context annotations
      #   X::Post.search_all("ruby", client: client, "post.fields": %w[author_id created_at text])
      def search_all(query, client:, **params)
        # @type self: singleton(Post)
        max_results = context_annotations?(params) ? Post::MAX_RESULTS : Post::MAX_ARCHIVE_RESULTS
        Cursor.__send__(:build, self, "tweets/search/all", client:, params: {query:, max_results:}.merge(params), min_results: 10)
      end

      # The posts of the authenticated user that other users have reposted
      #
      # The endpoint names no user, so these are always the posts of the user the client authenticates as.
      #
      # @api public
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] a cursor over the reposted posts
      # @example Print the reposted posts
      #   X::Post.reposts_of_me(client: client).each { |post| puts post.text }
      def reposts_of_me(client:, **params)
        # @type self: singleton(Post)
        Cursor.__send__(:build, self, "users/reposts_of_me", client:, params: {max_results: Post::MAX_RESULTS}.merge(params))
      end

      alias_method :retweets_of_me, :reposts_of_me

      private

      # Check whether a request asks for the context annotations of its posts
      # @api private
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Boolean] true if the post fields include context_annotations
      def context_annotations?(params)
        # @type self: singleton(Post)
        Utils.merge_params(default_params, params)["post.fields"].to_s.split(",").include?("context_annotations")
      end
    end
  end
end
