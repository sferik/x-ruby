require "monitor"
require_relative "page"
require_relative "problem"
require_relative "utils"

module X
  # A lazily paginated, cached, thread-safe collection of resources
  # @api public
  class Cursor
    include Enumerable

    # The query parameter most endpoints take the token of the next page in
    DEFAULT_TOKEN_PARAM = "pagination_token".freeze

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

    # The smallest page the endpoint accepts
    # @api public
    # @return [Integer] the minimum page size
    # @example Get the minimum page size of a search
    #   X::Post.search("ruby", client: client).min_results # => 10
    attr_reader :min_results

    # The query parameter the token of the next page is sent in
    # @api public
    # @return [String] the parameter name
    # @example Get the token parameter
    #   X::User.search("ruby", client: client).token_param # => "next_token"
    attr_reader :token_param

    # Initialize a new cursor
    #
    # @api public
    # @param klass [Class] the class of the resources in the collection
    # @param path [String] the endpoint path
    # @param client [Object] the client used to fetch pages
    # @param params [Hash] query parameters merged over the resource class's default parameters
    # @param prefetch [Boolean] whether to fetch the next page in a background thread while the current page is consumed
    # @param token_param [String] the query parameter the token of the next page is sent in
    # @param min_results [Integer] the smallest page the endpoint accepts, which first never asks below
    # @param limit [Integer, nil] the number of resources wanted, which sizes the pages and ends the cursor
    # @return [Cursor] a new cursor
    # @example Create a cursor over a user's followers
    #   X::Cursor.new(X::User, "users/7505382/followers", client: client, params: {max_results: 1000})
    # @example Create a cursor over an endpoint that pages with next_token
    #   X::Cursor.new(X::User, "users/search", client: client, params: {query: "ruby"}, token_param: "next_token")
    def initialize(klass, path, client:, params: {}, prefetch: false, token_param: DEFAULT_TOKEN_PARAM, min_results: 1, limit: nil)
      @klass = klass
      @client = client
      @path = path
      @params = Objects::Utils.merge_params(klass.default_params, params).freeze
      @prefetch = prefetch
      @token_param = token_param
      @min_results = min_results
      @limit = limit
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
    def prefetch? = @prefetch

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
    def refresh = self.class.new(klass, path, client:, params: own_params, prefetch: prefetch?, token_param:, min_results:)

    # Return a new cursor over the same collection with prefetching enabled
    #
    # @api public
    # @return [Cursor] a new cursor
    # @example Fetch every follower while overlapping requests with processing
    #   user.followers.prefetch.each { |follower| process(follower) }
    def prefetch = self.class.new(klass, path, client:, params: own_params, prefetch: true, token_param:, min_results:)

    # Return a new cursor over the same collection that yields stubs
    #
    # The requests ask for nothing but identifiers, and each resource is a stub holding only its identifier,
    # which hydrates on demand, even when the API returns a few default fields alongside it.
    #
    # @api public
    # @return [Cursor] a new cursor
    # @raise [NotImplementedError] if the resource class has no fields parameter
    # @example Check whether a user is among thousands of followers without fetching their fields
    #   user.followers.stubs.any?(other)
    def stubs = self.class.new(klass, path, client:, params: id_only_params, token_param:, min_results:)

    # The first resource, or the first few, requesting pages no larger than needed
    #
    # Iterating a cursor requests the largest page an endpoint allows, which costs the least in requests.
    # The API bills each resource returned, so first asks for a page of the size it needs instead, raised to
    # the endpoint's minimum, and each page after the first asks for no more than the pages before it left.
    # A page of the cursor's own size reuses its cache.
    #
    # @api public
    # @param count [Integer, nil] the number of resources, or nil for the first resource alone
    # @return [Objects::Resource, Array<Objects::Resource>, nil] the first resource, or the first resources
    # @example Read ten followers in one request for ten users
    #   user.followers.first(10)
    def first(count = nil)
      cursor = sized(count.to_i)
      count.nil? ? Enumerable.instance_method(:first).bind_call(cursor) : Enumerable.instance_method(:first).bind_call(cursor, count)
    end

    # The first few resources, requesting pages no larger than needed, as first does
    #
    # @api public
    # @param count [Integer] the number of resources
    # @return [Array<Objects::Resource>] the first resources
    # @raise [TypeError] if the count is not a number
    # @example Read three followers in one request for three users
    #   user.followers.take(3)
    def take(count) = first(Integer(count)) #: Array[Objects::Resource]

    # The identifiers of every resource, requesting nothing but identifiers
    #
    # @api public
    # @return [Array<Integer, String>] the identifiers, Integers unless the resource's identifiers are not numbers
    # @raise [NotImplementedError] if the resource class has no fields parameter
    # @example Get the identifiers of every follower
    #   user.followers.ids
    def ids = stubs.map(&:id)

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

    # A cursor with pages no larger than needed, within the endpoint's limits
    # @api private
    # @param count [Integer] the number of resources needed
    # @return [Cursor] this cursor, or a cursor with a smaller page size
    def sized(count)
      maximum = params["max_results"]
      return self if maximum.nil?

      maximum = Integer(maximum)
      count.eql?(maximum) ? self : with_max_results(count.clamp(min_results, maximum), count)
    end

    # A cursor over the same collection with another page size, stopping at a limit
    # @api private
    # @param size [Integer] the size of the first page
    # @param limit [Integer] the number of resources wanted
    # @return [Cursor] a new cursor
    def with_max_results(size, limit) = self.class.new(klass, path, client:, params: own_params.merge("max_results" => size), prefetch: prefetch?, token_param:, min_results:, limit:)

    # The parameters of this cursor, keeping dropped defaults dropped
    # @api private
    # @return [Hash{String => Object}] the parameters
    def own_params
      dropped = {} #: Hash[String, nil]
      klass.default_params.each_key { |key| dropped[key] = nil }
      dropped.merge(params)
    end

    # Check whether this cursor requests nothing but identifiers
    # @api private
    # @return [Boolean] true if the fields parameter selects only the identifier
    def id_only? = params[klass.fields_key].eql?(klass.id_key)

    # The query parameters that select nothing but the identifier
    # @api private
    # @return [Hash{String => Object}] the query parameters
    # @raise [NotImplementedError] if the resource class has no fields parameter
    def id_only_params
      fields_key = klass.fields_key || raise(NotImplementedError, "#{klass} has no fields parameter")
      dropped = {} #: Hash[String, nil]
      klass.default_params.each_key { |key| dropped[key] = nil }
      params.merge(dropped, fields_key => klass.id_key)
    end

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
      Page.new(resources_from(body), body.to_h["meta"].to_h, problems: Problem.all_from(body))
    end

    # Build the resources of a page, as stubs for a cursor of identifiers
    # @api private
    # @param body [Hash, nil] the response body
    # @return [Array<Objects::Resource>] the resources
    def resources_from(body)
      resources = klass.collection_from_response(body, client:, hydrated: true)
      id_only? ? resources.map { |resource| klass.from_id(resource, client:) } : resources
    end

    # Build the query parameters for a page, including the previous page token
    # @api private
    # @param index [Integer] the zero-based page index
    # @return [Hash{String => Object}, nil] the parameters or nil if the previous page was the last
    def page_params(index)
      return params if index.zero?

      token = cached_page(index - 1)&.next_token
      next_params(token) unless token.nil?
    end

    # The query parameters of a page, asking for what the pages before it left
    # @api private
    # @param token [String] the token of the next page
    # @return [Hash{String => Object}, nil] the parameters, or nil once the limit is fetched
    def next_params(token)
      paged = params.merge(token_param => token)
      limit = @limit
      return paged if limit.nil?

      remaining = limit - @pages.sum { |page| page.to_a.size }
      paged.merge("max_results" => remaining.clamp(min_results, Integer(params.fetch("max_results")))) if remaining.positive?
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
