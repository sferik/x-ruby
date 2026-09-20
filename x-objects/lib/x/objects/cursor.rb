require "json"
require_relative "page"
require_relative "pages"
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
    #   user.followers.resource_class # => X::User
    attr_reader :resource_class

    # The client the resources hold, which also fetches the pages unless app_only?
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
    # @param resource_class [Class] the class of the resources in the collection
    # @param path [String] the endpoint path
    # @param client [Object] the client the resources hold, which fetches the pages unless the endpoint takes
    #   app-only authentication
    # @param params [Hash] query parameters merged over the resource class's default parameters
    # @param prefetch [Boolean] whether to fetch the next page in a background thread while the current page is consumed
    # @param token_param [String] the query parameter the token of the next page is sent in
    # @param min_results [Integer] the smallest page the endpoint accepts, which first never asks below
    # @param app_only [Boolean] internal to the object layer, which may change it within 1.x: whether the pages are
    #   fetched with the app-only client of the client, for an endpoint that refuses the OAuth 1.0a of a user, while
    #   the resources hold the client, so that they act as the user
    # @param total [Proc, nil] internal to the object layer, which may change it within 1.x: a block returning the
    #   number of resources the API publishes for the collection
    # @return [Cursor] a new cursor
    # @example Create a cursor over a user's followers
    #   X::Cursor.new(X::User, "users/7505382/followers", client: client, params: {max_results: 1000})
    # @example Create a cursor over an endpoint that pages with next_token
    #   X::Cursor.new(X::User, "users/search", client: client, params: {query: "ruby"}, token_param: "next_token")
    def initialize(resource_class, path, client:, params: {}, prefetch: false, token_param: DEFAULT_TOKEN_PARAM, min_results: 1, app_only: false, total: nil)
      @resource_class = resource_class
      @client = client
      @path = path
      @params = Objects::Utils.merge_params(resource_class.default_params, params).freeze
      @prefetch, @app_only = prefetch, app_only
      @token_param = token_param
      @min_results = min_results
      @total = total
      @pages = Objects::Pages.new(self)
      freeze
    end

    # Check whether the next page is fetched in the background
    #
    # @api public
    # @return [Boolean] true if pages are prefetched
    # @example Check whether a cursor prefetches
    #   cursor.prefetch? # => false
    def prefetch? = @prefetch

    # Check whether the pages are fetched with the app-only client of the client
    #
    # The space endpoints refuse the OAuth 1.0a of a user, so a cursor over one fetches its pages with the app-only
    # client, while its resources hold the client, so that they act as the user.
    #
    # @api public
    # @return [Boolean] true if pages are fetched as the app
    # @example Check whether a cursor fetches as the app
    #   space.posts.app_only? # => true
    def app_only? = @app_only

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
    # The pages before the one asked for are read first, since the token of each asks for the next.
    #
    # @api public
    # @param index [Integer] the zero-based page index
    # @return [Page, nil] the page or nil if the collection has fewer pages
    # @raise [ArgumentError] if the index is negative, since pages are read forward from the first
    # @example Fetch the first page
    #   user.followers.page(0)
    def page(index) = @pages.at(index)

    # Return a new cursor over the same collection with an empty page cache
    #
    # @api public
    # @return [Cursor] a new cursor
    # @example Iterate again with fresh data
    #   followers = user.followers.refresh
    def refresh = self.class.new(resource_class, path, client:, params: own_params, prefetch: prefetch?, token_param:, min_results:, app_only: app_only?, total: @total)

    # Return a new cursor over the same collection with prefetching enabled
    #
    # @api public
    # @return [Cursor] a new cursor
    # @example Fetch every follower while overlapping requests with processing
    #   user.followers.prefetch.each { |follower| process(follower) }
    def prefetch = self.class.new(resource_class, path, client:, params: own_params, prefetch: true, token_param:, min_results:, app_only: app_only?, total: @total)

    # Return a new cursor over the same collection that yields stubs
    #
    # The requests ask for nothing but identifiers, and each resource is a stub holding only its identifier,
    # which hydrates on demand, even when the API returns a few default fields alongside it.
    #
    # @api public
    # @return [Cursor] a new cursor
    # @raise [UnsupportedOperation] if the resource class has no fields parameter
    # @example Check whether a user is among thousands of followers without fetching their fields
    #   user.followers.stubs.any?(other)
    def stubs = self.class.new(resource_class, path, client:, params: id_only_params, prefetch: prefetch?, token_param:, min_results:, app_only: app_only?, total: @total)

    # The first resource, or the first few, requesting pages no larger than needed
    #
    # Iterating a cursor requests the largest page an endpoint allows, which costs the least in requests.
    # The API bills each resource returned, so first asks for a page of the size it needs instead, raised to
    # the endpoint's minimum, and each page after the first asks for no more than the pages before it left.
    # The API may serve an empty page with the token of the next, having left out what it filters, such as
    # suspended users, so first reads on until it finds a resource. The cursor keeps the pages first reads, as it
    # keeps every page, so a cursor whose pages already hold what is asked for answers from them, without a request,
    # and an iteration after first requests only what first left.
    #
    # @api public
    # @param count [Integer, nil] the number of resources, or nil for the first resource alone
    # @return [Objects::Resource, Array<Objects::Resource>, nil] the first resource, or the first resources
    # @raise [ArgumentError] if the count is negative
    # @example Read ten followers in one request for ten users
    #   user.followers.first(10)
    def first(count = nil)
      resources = @pages.read(count || 1) #: Array[untyped]
      return resources unless count.nil?

      resource, = resources
      resource
    end

    # The first few resources, requesting pages no larger than needed, as first does
    #
    # @api public
    # @param count [Integer] the number of resources
    # @return [Array<Objects::Resource>] the first resources
    # @raise [TypeError] if the count is not a number
    # @example Read three followers in one request for three users
    #   user.followers.take(3)
    def take(count) = first(Integer(count))

    # Check whether the collection holds any resource, requesting one
    #
    # Without a pattern or a block, this asks for a single resource rather than a full page.
    #
    # @api public
    # @param pattern [Object] a pattern each resource is matched against
    # @yield [Objects::Resource] each resource
    # @return [Boolean] true if any resource matches
    # @example Check whether a user has any followers
    #   user.followers.any?
    def any?(*pattern, &block)
      return super unless pattern.empty? && block.nil?

      !first.nil?
    end

    # Check whether the collection holds no resource, requesting one
    #
    # Without a pattern or a block, this asks for a single resource rather than a full page.
    #
    # @api public
    # @param pattern [Object] a pattern each resource is matched against
    # @yield [Objects::Resource] each resource
    # @return [Boolean] true if no resource matches
    # @example Check whether a user follows nobody
    #   user.following.none?
    def none?(*pattern, &block)
      return super unless pattern.empty? && block.nil?

      first.nil?
    end

    # Check whether the collection is empty, requesting one resource
    #
    # Like none? without a pattern or a block, this asks for a single resource rather than a full page.
    #
    # @api public
    # @return [Boolean] true if the collection holds no resource
    # @example Check whether a user has no followers
    #   user.followers.empty?
    def empty? = first.nil?

    # Check whether the collection holds one resource, requesting two
    #
    # Without a pattern or a block, this asks for two resources rather than a full page.
    #
    # @api public
    # @param pattern [Object] a pattern each resource is matched against
    # @yield [Objects::Resource] each resource
    # @return [Boolean] true if exactly one resource matches
    # @example Check whether a list has a single member
    #   list.members.one?
    def one?(*pattern, &block)
      return super unless pattern.empty? && block.nil?

      take(2).size.eql?(1)
    end

    # The number the API publishes for the collection, without reading any of it
    #
    # The API publishes a number for a user's followers, followed users, and list memberships, and for a list's
    # members and followers. Reading it costs no request when the user or list holds it, and one lookup when it is a
    # stub. The number counts what the collection holds, which can differ from what count reads, since the
    # endpoint leaves out what the authenticated user cannot see, such as private lists and suspended users. count
    # instead reads every page of the collection, a request per page, and the API bills each resource. A cursor
    # answers no size, so that Ruby's own methods, such as each_slice and lazy, do not page a collection to size it.
    #
    # @api public
    # @return [Integer, nil] the published number, or nil for a collection the API publishes no number for
    # @example Count a user's followers without reading one of them
    #   user.followers.published_count # => 12345
    def published_count = @total&.call

    # The identifiers of every resource, requesting nothing but identifiers
    #
    # @api public
    # @return [Array<Integer, String>] the identifiers, Integers unless the resource's identifiers are not numbers
    # @raise [UnsupportedOperation] if the resource class has no fields parameter
    # @example Get the identifiers of every follower
    #   user.followers.ids
    def ids = stubs.map(&:id)

    # Every resource of the collection, as a JSON encoder and ActiveSupport read them
    #
    # Serializing a cursor reads every page of the collection, a request per page, and the API bills each resource
    # it returns, so serialize what first or take read instead when the whole collection is not wanted.
    #
    # @api public
    # @return [Array<Objects::Resource>] the resources
    # @example Serialize the first ten followers rather than every one of them
    #   user.followers.first(10).as_json
    def as_json(*) = to_a

    # The collection as a JSON array of attributes, reading every page
    #
    # @api public
    # @param state [JSON::State, nil] the state a JSON encoder passes, which the attributes are given
    # @return [String] the resources as a JSON array
    # @example Serialize a whole collection
    #   list.members.to_json # => "[{\"id\":\"7505382\"}]"
    def to_json(state = nil) = as_json.to_json(state)

    # Summarize the cursor for the console
    #
    # @api public
    # @return [String] the class name, resource class, and path
    # @example Inspect a cursor
    #   user.followers.inspect # => #<X::Cursor resource_class=X::User path="users/7505382/followers">
    def inspect
      "#<#{self.class} resource_class=#{resource_class} path=#{path.inspect}>"
    end

    private

    # The parameters of this cursor, keeping dropped defaults dropped
    # @api private
    # @return [Hash{String => Object}] the parameters
    def own_params
      dropped = {} #: Hash[String, nil]
      resource_class.default_params.each_key { |key| dropped[key] = nil }
      dropped.merge(params)
    end

    # The query parameters that select nothing but the identifier
    # @api private
    # @return [Hash{String => Object}] the query parameters
    # @raise [UnsupportedOperation] if the resource class has no fields parameter
    def id_only_params
      fields_key = resource_class.fields_key || raise(UnsupportedOperation, "#{resource_class} has no fields parameter")
      dropped = {} #: Hash[String, nil]
      resource_class.default_params.each_key { |key| dropped[key] = nil }
      params.merge(dropped, fields_key => resource_class.id_key)
    end
  end
end
