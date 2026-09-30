# frozen_string_literal: true

require_relative "memo"
require_relative "page"
require_relative "pages"
require_relative "utils"

module X
  module Objects
    # A lazily paginated, cached, thread-safe collection of resources
    # @api public
    class ::X::Cursor
      include Enumerable

      # The query parameter most endpoints take the token of the next page in
      DEFAULT_TOKEN_PARAM = "pagination_token"
      private_constant :DEFAULT_TOKEN_PARAM
      # The message raised for a cursor serialized whole, which would read every page of its collection
      SERIALIZATION_MESSAGE = "Serializing a cursor would read every page of its collection, a billed request per " \
        "page; serialize cursor.first(n), or cursor.to_a to read every page"
      private_constant :SERIALIZATION_MESSAGE

      # The class of the resources in this collection
      # @api public
      # @return [Class] the resource class
      # @example Get the resource class
      #   user.followers.resource_class # => X::User
      attr_reader :resource_class

      # The client the resources hold, which also fetches the pages
      #
      # The pages of an endpoint that refuses OAuth 1.0a, such as the posts of a space, are fetched with the app-only
      # client of a client that signs with it, while the resources hold the client itself.
      #
      # @api public
      # @return [Object] the client
      # @example Get the client
      #   cursor.client
      attr_reader :client

      # The endpoint path
      #
      # Internal to x-objects: the pages of a cursor are requested at it, and the endpoint a collection is read from may
      # change within 1.x, as the API moves one.
      #
      # @api private
      # @return [String] the endpoint path
      # @example Get the path
      #   user.followers.path # => "users/7505382/followers"
      attr_reader :path

      # The query parameters sent with every page request
      #
      # Internal to x-objects: the pages of a cursor are requested with them, and they hold the default fields of the
      # resource class, which a minor release may add to, and the size of a page, which it may change.
      #
      # @api private
      # @return [Hash{String => Object}] the query parameters
      # @example Get the parameters
      #   user.followers.params["max_results"] # => 1000
      attr_reader :params

      # Build a cursor
      #
      # Internal to x-objects: a resource builds the cursors of its collections, and the searches and lookups build
      # theirs, with it, and new is private, so that the settings a cursor pages with can change within 1.x, as the
      # readers of the token parameter, the smallest page, and whether the pages are fetched as the app are private for
      # the same reason. A cursor is made from another with refresh, prefetch, and stubs.
      #
      # @api private
      # @param resource_class [Class] the class of the resources in the collection
      # @param path [String] the endpoint path
      # @param client [Object] the client the resources hold, which fetches the pages unless the endpoint takes
      #   app-only authentication
      # @param params [Hash] query parameters merged over the resource class's default parameters
      # @param prefetch [Boolean] whether to fetch the next page in a background thread while the current page is consumed
      # @param token_param [String] the query parameter the token of the next page is sent in
      # @param min_results [Integer] the smallest page the endpoint accepts, which first never asks below
      # @param app_only [Boolean] whether the pages are fetched with the app-only client of the client, for an endpoint
      #   that refuses the OAuth 1.0a of a user, while the resources hold the client, so that they act as the user
      # @param total [Proc, nil] a block returning the number of resources the API publishes for the collection, which
      #   reads it again when given fresh: true
      # @param ids_only [Boolean] whether the endpoint gives the resources by their identifiers alone, and takes none of
      #   their fields, so the pages ask for none of the default parameters, and read stubs that hydrate together
      # @return [Cursor] a new cursor
      # @example Build a cursor over the followers of a user, which counts them with followers_count
      #   X::Cursor.__send__(:build, X::User, "users/7505382/followers", client: client, total: ->(fresh: false) { 42 })
      # @example Build a cursor over an endpoint that pages with next_token
      #   X::Cursor.__send__(:build, X::User, "users/search", client: client, params: {query: "ruby"}, token_param: "next_token")
      def self.build(resource_class, path, client:, params: {}, prefetch: false, token_param: DEFAULT_TOKEN_PARAM, min_results: 1, app_only: false, total: nil, ids_only: false)
        allocate.tap { |cursor| cursor.__send__(:setup, resource_class, path, client:, params:, prefetch:, token_param:, min_results:, app_only:, total:, ids_only:) }
      end
      private_class_method :new, :build

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
      # @yield [Resource] each resource
      # @return [Enumerator, Cursor] an enumerator without a block, otherwise self
      # @example Print every follower
      #   user.followers.each { |follower| puts follower.username }
      def each(&block)
        return to_enum unless block

        each_page { |page| page.each(&block) }
      end

      # Iterate over every page, fetching pages as needed
      #
      # The pages are those {#page} reads, as they were fetched, so a page need not hold as many resources as the
      # largest page the endpoint allows.
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
      # The pages before the one asked for are read first, since the token of each asks for the next. A page is the
      # page as it was fetched and kept, whatever fetched it: iterating fetches the largest page the endpoint allows,
      # but first, take, any?, and empty? fetch pages no larger than they need, which the cursor keeps too, so that
      # an iteration after them does not pay again for what they read. After user.followers.first, the first page
      # holds one follower, and the pages an iteration fetches after it as many as the largest page does. The API may
      # serve a page with fewer resources than it was asked for, or none, so no page has a size to rely on.
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
      # The number the API publishes for the collection is read again too, once, the first time published_count asks
      # for it, since the collection it counts may have changed.
      #
      # @api public
      # @return [Cursor] a new cursor
      # @example Iterate again with fresh data
      #   followers = user.followers.refresh
      def refresh = self.class.__send__(:build, resource_class, path, client:, params: own_params, prefetch: prefetch?, token_param:, min_results:, app_only: app_only?, total: fresh_total, ids_only: ids_only?)

      # Return a new cursor over the same collection with prefetching enabled
      #
      # @api public
      # @return [Cursor] a new cursor
      # @example Fetch every follower while overlapping requests with processing
      #   user.followers.prefetch.each { |follower| process(follower) }
      def prefetch = self.class.__send__(:build, resource_class, path, client:, params: own_params, prefetch: true, token_param:, min_results:, app_only: app_only?, total: @total, ids_only: ids_only?)

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
      def stubs = self.class.__send__(:build, resource_class, path, client:, params: id_only_params, prefetch: prefetch?, token_param:, min_results:, app_only: app_only?, total: @total, ids_only: true)

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
      # @param count [Integer, nil] the number of resources, or nil for the first resource alone; a Float is read as
      #   the Integer it converts to, as Array#first reads it
      # @return [Resource, Array<Resource>, nil] the first resource, or the first resources, frozen
      # @raise [ArgumentError] if the count is negative
      # @raise [TypeError] if the count is not a number that converts to an Integer
      # @example Read ten followers in one request for ten users
      #   user.followers.first(10)
      def first(count = nil)
        resources = @pages.read(count.nil? ? 1 : Utils.count!(count)) #: Array[untyped]
        return resources unless count.nil?

        resource, = resources
        resource
      end

      # Every resource, fetching every page
      #
      # The array is frozen, as the arrays first and take return are, since a cursor keeps the pages it read and a
      # caller that changed what it returned would change nothing the cursor holds.
      #
      # @api public
      # @return [Array<Resource>] every resource, frozen
      # @example Read every follower
      #   user.followers.to_a
      def to_a = super.freeze

      alias_method :entries, :to_a

      # The first few resources, requesting pages no larger than needed, as first does
      #
      # @api public
      # @param count [Integer] the number of resources; a Float is read as the Integer it converts to, as Array#take
      #   reads it
      # @return [Array<Resource>] the first resources, frozen
      # @raise [ArgumentError] if the count is negative
      # @raise [TypeError] if the count is not a number that converts to an Integer, such as nil or a String
      # @example Read three followers in one request for three users
      #   user.followers.take(3)
      def take(count) = first(Utils.count!(count))

      # Check whether the collection holds any resource, requesting one
      #
      # Without a pattern or a block, this asks for a single resource rather than a full page.
      #
      # @api public
      # @param pattern [Object] a pattern each resource is matched against
      # @yield [Resource] each resource
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
      # @yield [Resource] each resource
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
      # @yield [Resource] each resource
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
      # @return [Array<Integer, String>] the identifiers, Integers unless the resource's identifiers are not numbers,
      #   frozen
      # @raise [UnsupportedOperation] if the resource class has no fields parameter
      # @example Get the identifiers of every follower
      #   user.followers.ids
      def ids = stubs.map(&:id).freeze

      # Refuse to write the collection as JSON, which would read every page of it
      #
      # Serializing a cursor would read every page of the collection, a request per page, and the API bills each
      # resource it returns, from a call that says nothing of it, such as a cursor in a Hash that a log or a render
      # writes. It raises instead, as ActiveSupport would otherwise read a cursor as the Enumerable it is. Serialize what
      # first(n) or to_a reads instead, each of which says at the call how much it reads.
      #
      # @api public
      # @return [void]
      # @raise [UnsupportedOperation] always
      # @example Serialize the first ten followers rather than every one of them
      #   user.followers.first(10).as_json
      def as_json(*) = raise(UnsupportedOperation, SERIALIZATION_MESSAGE)

      # Refuse to write the collection as a JSON array, which would read every page
      #
      # It raises as {#as_json} does, for the reason that says.
      #
      # @api public
      # @param _state [JSON::State, nil] the state a JSON encoder passes
      # @return [void]
      # @raise [UnsupportedOperation] always
      # @example Serialize a whole collection, reading every page of it
      #   list.members.to_a.to_json # => "[{\"id\":\"7505382\"}]"
      def to_json(_state = nil) = raise(UnsupportedOperation, SERIALIZATION_MESSAGE)

      # Refuse to write the cursor with Marshal, as it refuses to write it as JSON
      #
      # A cursor holds its client, and the threads and locks that fetch its pages, none of which Marshal can write, and
      # caching the collection it names would mean reading every page of it, as {#as_json} says. It raises the
      # TypeError Marshal raises for what it cannot write, with the message of {#as_json}, rather than the one Marshal
      # would raise from within the cursor. Marshal what first(n) or to_a reads, or a page, instead.
      #
      # @api public
      # @return [void]
      # @raise [TypeError] always
      # @example Cache the first page of the followers of a user rather than the cursor
      #   Rails.cache.write("followers", user.followers.page(0))
      def marshal_dump = raise(TypeError, SERIALIZATION_MESSAGE)

      # Refuse to write the cursor as YAML, as it refuses Marshal
      #
      # YAML reads no marshal_dump, and would write every instance variable of the cursor, its client and the
      # credentials it holds among them, so it raises as {#marshal_dump} does. Write what first(n) or to_a reads, or a
      # page, instead.
      #
      # @api public
      # @param _coder [Psych::Coder] the coder YAML would write the cursor with
      # @return [void]
      # @raise [TypeError] always
      # @example Write the first page of the followers of a user as YAML rather than the cursor
      #   YAML.dump(user.followers.page(0))
      def encode_with(_coder) = raise(TypeError, SERIALIZATION_MESSAGE)

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

      # Set the collection, requests, and pages of a new cursor, and freeze it
      # @api private
      # @return [void]
      def setup(resource_class, path, client:, params:, prefetch:, token_param:, min_results:, app_only:, total:, ids_only:)
        @resource_class = resource_class
        @client = client
        @path = path
        @params = Utils.merge_params(ids_only ? {} : resource_class.default_params, params).freeze
        @prefetch, @app_only, @ids_only = prefetch, app_only, ids_only
        @token_param = token_param
        @min_results = min_results
        @total = total
        @pages = Pages.new(self)
        freeze
      end

      # The smallest page the endpoint accepts
      #
      # Internal to x-objects: Pages never asks for a smaller page than this.
      #
      # @api private
      # @return [Integer] the minimum page size
      attr_reader :min_results

      # The query parameter the token of the next page is sent in
      #
      # Internal to x-objects: Pages sends the token of each page after the first in it.
      #
      # @api private
      # @return [String] the parameter name
      attr_reader :token_param

      # Check whether the pages are fetched with the app-only client of the client
      #
      # The space endpoints refuse the OAuth 1.0a of a user, so a cursor over one fetches its pages with the app-only
      # client, while its resources hold the client, so that they act as the user. Internal to x-objects: Pages asks
      # it which client fetches a page.
      #
      # @api private
      # @return [Boolean] true if pages are fetched as the app
      def app_only? = @app_only

      # Check whether the endpoint gives the resources by their identifiers alone
      #
      # Such an endpoint takes none of their fields either. Internal to x-objects: the pages of such a cursor read stubs, which is what Pages asks it for this.
      #
      # @api private
      # @return [Boolean] true if the pages ask for none of the default parameters, and read stubs
      def ids_only? = @ids_only

      # The block of a refreshed cursor, which reads the published number again once
      # @api private
      # @return [Proc, nil] the block, or nil for a collection the API publishes no number for
      def fresh_total
        total = @total or return
        count = Memo.new
        lambda do |fresh: false|
          # @type var fresh: bool
          fresh ? total.call(fresh: true) : count.fetch { total.call(fresh: true) }
        end
      end

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
        return params if ids_only?

        fields_key = resource_class.__send__(:fields_key) || raise(UnsupportedOperation, "#{resource_class} has no fields parameter") #: String
        id_key = resource_class.__send__(:id_key) #: String
        dropped = {} #: Hash[String, nil]
        resource_class.default_params.each_key { |key| dropped[key] = nil }
        params.merge(dropped, fields_key => id_key)
      end
    end
  end
end
