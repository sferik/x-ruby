require "monitor"
require_relative "page"
require_relative "utils"

module X
  # A lazily paginated, cached, thread-safe collection of resources
  # @api public
  class Cursor
    include Enumerable

    # The class of the resources in this collection
    # @api public
    # @return [Class] the resource class
    # @example Get the resource class
    #   user.followers.klass # => X::User
    attr_reader :klass

    # The client used to fetch pages
    # @api public
    # @return [Object] the client
    # @example Get the client
    #   cursor.client
    attr_reader :client

    # The endpoint path
    # @api public
    # @return [String] the endpoint path
    # @example Get the path
    #   user.followers.path # => "users/7505382/followers"
    attr_reader :path

    # The query parameters sent with every page request
    # @api public
    # @return [Hash{String => Object}] the query parameters
    # @example Get the parameters
    #   user.followers.params["max_results"] # => 1000
    attr_reader :params

    # Initialize a new cursor
    #
    # @api public
    # @param klass [Class] the class of the resources in the collection
    # @param client [Object] the client used to fetch pages
    # @param path [String] the endpoint path
    # @param params [Hash] query parameters merged over the resource class's default parameters
    # @param prefetch [Boolean] whether to fetch the next page in a background thread while the current page is consumed
    # @return [Cursor] a new cursor
    # @example Create a cursor over a user's followers
    #   X::Cursor.new(X::User, client: client, path: "users/7505382/followers", params: {max_results: 1000})
    def initialize(klass, client:, path:, params: {}, prefetch: false)
      @klass = klass
      @client = client
      @path = path
      @params = Objects::Utils.merge_params(klass.default_params, params).freeze
      @prefetch = prefetch
      @monitor = Monitor.new
      @pages = []
      freeze
    end

    # Check whether the next page is fetched in the background
    #
    # @api public
    # @return [Boolean] true if pages are prefetched
    # @example Check whether a cursor prefetches
    #   cursor.prefetch? # => false
    def prefetch?
      @prefetch
    end

    # Iterate over every resource, fetching pages as needed
    #
    # @api public
    # @yield [Objects::Resource] each resource
    # @return [Enumerator, Cursor] an enumerator without a block, otherwise self
    # @example Print every follower
    #   user.followers.each { |follower| puts follower.username }
    def each(&block)
      return to_enum unless block

      each_page { |page| page.each(&block) }
    end

    # Iterate over every page, fetching pages as needed
    #
    # @api public
    # @yield [Page] each page
    # @return [Enumerator, Cursor] an enumerator without a block, otherwise self
    # @example Print the size of every page
    #   user.followers.each_page { |page| puts page.result_count }
    def each_page
      return to_enum(:each_page) unless block_given?

      index = 0
      while (current = page(index))
        yield current
        index += 1
      end
      self
    end

    # Fetch a page by index, using the cache when possible
    #
    # @api public
    # @param index [Integer] the zero-based page index
    # @return [Page, nil] the page or nil if the collection has fewer pages
    # @example Fetch the first page
    #   user.followers.page(0)
    def page(index)
      current = cached_page(index)
      prefetch_page(index + 1) if prefetch? && current&.next_token
      current
    end

    # Return a new cursor over the same collection with an empty page cache
    #
    # @api public
    # @return [Cursor] a new cursor
    # @example Iterate again with fresh data
    #   followers = user.followers.refresh
    def refresh
      self.class.new(klass, client:, path:, params:, prefetch: prefetch?)
    end

    # Return a new cursor over the same collection with prefetching enabled
    #
    # @api public
    # @return [Cursor] a new cursor
    # @example Fetch every follower while overlapping requests with processing
    #   user.followers.prefetch.each { |follower| process(follower) }
    def prefetch
      self.class.new(klass, client:, path:, params:, prefetch: true)
    end

    # Summarize the cursor for the console
    #
    # @api public
    # @return [String] the class name, resource class, and path
    # @example Inspect a cursor
    #   user.followers.inspect # => #<X::Cursor klass=X::User path="users/7505382/followers">
    def inspect
      "#<#{self.class} klass=#{klass} path=#{path.inspect}>"
    end

    private

    # Fetch a page by index, storing it in the cache
    # @api private
    # @param index [Integer] the zero-based page index
    # @return [Page, nil] the page or nil if the collection has fewer pages
    def cached_page(index)
      @monitor.synchronize { @pages[index] ||= fetch_page(index) }
    end

    # Fetch a page from the API
    # @api private
    # @param index [Integer] the zero-based page index
    # @return [Page, nil] the page or nil if the previous page was the last
    def fetch_page(index)
      page_params = page_params(index)
      return if page_params.nil?

      body = client.get(Objects::Utils.path(path, page_params), **Objects::Utils::JSON_CLASSES)
      Page.new(items: klass.collection_from_response(body, client:), meta: body.to_h["meta"].to_h)
    end

    # Build the query parameters for a page, including the previous page token
    # @api private
    # @param index [Integer] the zero-based page index
    # @return [Hash{String => Object}, nil] the parameters or nil if the previous page was the last
    def page_params(index)
      return params if index.zero?

      token = cached_page(index - 1)&.next_token
      params.merge("pagination_token" => token) unless token.nil?
    end

    # Fetch a page in a background thread; errors resurface when the page is requested
    # @api private
    # @param index [Integer] the zero-based page index
    # @return [Thread] the background thread
    def prefetch_page(index)
      Thread.new do
        cached_page(index)
      rescue
        nil
      end
    end
  end
end
