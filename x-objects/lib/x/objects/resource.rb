require_relative "attributes"
require_relative "identity"
require_relative "includes"
require_relative "memo"
require_relative "parallel"
require_relative "utils"

module X
  module Objects
    # Base class for immutable API resources with identity, references, and hydration
    # @api public
    class Resource
      extend Attributes
      include Identity

      # Maximum number of identifiers accepted by a batch lookup endpoint
      MAX_BATCH_SIZE = 100

      # The frozen attributes returned by the API
      # @api public
      # @return [Hash{String => Object}] the attributes
      # @example Get the raw attributes
      #   user.attrs # => {"id" => "7505382", "name" => "Erik Berlin", "username" => "sferik"}
      attr_reader :attrs

      # The client used to fetch this resource and its references
      # @api public
      # @return [Object, nil] the client
      # @example Get the client
      #   user.client
      attr_reader :client

      # The identity map of the response this resource came from
      # @api private
      # @return [Includes] the identity map
      attr_reader :includes

      # @!method to_h
      #   Alias for attrs, returns the frozen attributes
      #   @api public
      #   @return [Hash{String => Object}] the attributes
      #   @example Convert a resource to a hash
      #     user.to_h
      alias_method :to_h, :attrs

      class << self
        # The API endpoint used to look up this resource by identifier
        #
        # @api public
        # @return [String, nil] the endpoint or nil if the resource cannot be looked up
        # @example Get the endpoint
        #   X::User.endpoint # => "users"
        def endpoint
        end

        # The attribute holding the identifier
        #
        # @api public
        # @return [String] the identifier key
        # @example Get the identifier key
        #   X::Media.id_key # => "media_key"
        def id_key
          "id"
        end

        # The key under which this resource appears in the includes of a response
        #
        # @api public
        # @return [String, nil] the includes key or nil if the resource is never expanded
        # @example Get the includes key
        #   X::User.includes_key # => "users"
        def includes_key
        end

        # The default query parameters requesting every field and expansion
        #
        # @api public
        # @return [Hash{String => String}] the default query parameters
        # @example Get the default parameters
        #   X::User.default_params
        def default_params
          {}
        end

        # Check whether this resource can be looked up by identifier
        #
        # @api public
        # @return [Boolean] true if the resource has a lookup endpoint
        # @example Check whether a resource is hydratable
        #   X::Media.hydratable? # => false
        def hydratable?
          !endpoint.nil?
        end

        # The lookup endpoint, which must exist
        #
        # @api public
        # @return [String] the endpoint
        # @raise [NotImplementedError] if the resource cannot be looked up by identifier
        # @example Get the lookup endpoint
        #   X::User.endpoint! # => "users"
        def endpoint!
          endpoint || raise(NotImplementedError, "#{self} cannot be fetched by #{id_key}")
        end

        # Look up a resource by identifier
        #
        # @api public
        # @param id [String, Integer, Resource] the identifier
        # @param client [Object] the client used to make the request
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Resource, nil] the resource or nil if it was not found
        # @example Look up a user by identifier
        #   X::User.find("7505382", client: client)
        def find(id, client:, **params) # steep:ignore MethodBodyTypeMismatch
          lookup("#{endpoint!}/#{Utils.id_of(id)}", client:, **params)
        end

        # Look up many resources by identifier, in parallel batches
        #
        # @api public
        # @param ids [Array<String, Integer, Resource>] the identifiers
        # @param client [Object] the client used to make the requests
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Resource>] the resources that were found
        # @example Look up many users by identifier
        #   X::User.find_all(["7505382", "12"], client: client)
        def find_all(ids, client:, **params)
          batches = ids.map { |id| Utils.id_of(id) }.each_slice(MAX_BATCH_SIZE)
          Parallel.map(batches) { |batch| lookup_all(endpoint!, client:, ids: batch, **params) }.flatten
        end

        # Fetch a single resource from an endpoint
        #
        # @api public
        # @param path [String] the endpoint path
        # @param client [Object] the client used to make the request
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Resource, nil] the resource or nil if the response has no data
        # @example Fetch the authenticated user
        #   X::User.lookup("users/me", client: client)
        def lookup(path, client:, **params) # steep:ignore MethodBodyTypeMismatch
          from_response(get(path, client:, params:), client:)
        end

        # Fetch a list of resources from an endpoint without paginating
        #
        # @api public
        # @param path [String] the endpoint path
        # @param client [Object] the client used to make the request
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Resource>] the resources
        # @example Fetch users by username
        #   X::User.lookup_all("users/by", client: client, usernames: ["sferik", "gem"])
        def lookup_all(path, client:, **params) # steep:ignore MethodBodyTypeMismatch
          collection_from_response(get(path, client:, params:), client:)
        end

        # Build a resource from a response with a single data object
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the resource holds every requested field
        # @return [Resource, nil] the resource or nil if the response has no data
        # @example Build a user from a response
        #   X::User.from_response({"data" => {"id" => "7505382"}}, client: client)
        def from_response(body, client:, hydrated: true) # steep:ignore MethodBodyTypeMismatch
          body = body.to_h
          data = body["data"]
          return unless data.is_a?(Hash)

          new(data, client:, includes: Includes.new(body["includes"]), hydrated:)
        end

        # Build resources from a response with a data array
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @return [Array<Resource>] the resources
        # @example Build users from a response
        #   X::User.collection_from_response({"data" => [{"id" => "7505382"}]}, client: client)
        def collection_from_response(body, client:) # steep:ignore MethodBodyTypeMismatch
          body = body.to_h
          data = body["data"]
          data = nil unless data.is_a?(Array)
          includes = Includes.new(body["includes"])
          Array(data).map { |attrs| new(attrs, client:, includes:, hydrated: true) }.freeze
        end

        private

        # Request an endpoint with the default parameters
        # @api private
        # @param path [String] the endpoint path
        # @param client [Object] the client used to make the request
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Hash, nil] the parsed response body
        def get(path, client:, params:)
          client.get(Utils.path(path, Utils.merge_params(default_params, params)), **Utils::JSON_CLASSES)
        end
      end

      # Initialize a new immutable resource
      #
      # @api public
      # @param attrs [Hash] the attributes, which must include the identifier
      # @param client [Object, nil] the client used to fetch references
      # @param includes [Includes] the identity map of the response the resource came from
      # @param hydrated [Boolean] whether the resource holds every requested field
      # @return [Resource] a new resource
      # @raise [ArgumentError] if the attributes do not include the identifier
      # @example Create a user from attributes
      #   X::User.new({"id" => "7505382", "username" => "sferik"}, client: client)
      def initialize(attrs, client: nil, includes: Includes.new, hydrated: false)
        @attrs = Utils.deep_freeze(attrs)
        raise ArgumentError, "#{self.class} requires #{self.class.id_key}" if @attrs[self.class.id_key].nil?

        @client = client
        @includes = includes
        @hydrated = hydrated
        @memo = Memo.new
        freeze
      end

      # The identifier
      #
      # @api public
      # @return [String] the identifier
      # @example Get the identifier
      #   user.id # => "7505382"
      def id
        attrs.fetch(self.class.id_key)
      end

      # Check whether the resource was the primary subject of an API response
      #
      # @api public
      # @return [Boolean] true if the resource holds every requested field
      # @example Check whether a referenced user is hydrated
      #   post.author.hydrated? # => false
      def hydrated?
        @hydrated
      end

      # Fetch the full resource, memoizing the result
      #
      # @api public
      # @return [Resource, nil] the full resource or nil if it no longer exists
      # @raise [NotImplementedError] if the resource cannot be looked up by identifier
      # @raise [ArgumentError] if the resource has no client
      # @example Fetch the full author of a post
      #   post.author.hydrate.description
      def hydrate
        @memo.fetch { hydrated? ? self : fetch }
      end

      # Fetch the full resource again, replacing the memoized result
      #
      # @api public
      # @return [Resource, nil] the fresh resource or nil if it no longer exists
      # @raise [NotImplementedError] if the resource cannot be looked up by identifier
      # @raise [ArgumentError] if the resource has no client
      # @example Refresh a user's follower count
      #   user.refresh.followers_count
      def refresh
        @memo.store(fetch)
      end

      # Summarize the resource for the console
      #
      # @api public
      # @return [String] the class name and attributes
      # @example Inspect a user
      #   user.inspect # => #<X::User id="7505382" username="sferik">
      def inspect
        "#<#{self.class} #{attrs.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")}>"
      end

      private

      # Fetch the full resource from the API
      # @api private
      # @return [Resource, nil] the full resource or nil if it no longer exists
      def fetch # steep:ignore MethodBodyTypeMismatch
        self.class.lookup("#{self.class.endpoint!}/#{id}", client: client!)
      end

      # The client, which must exist
      # @api private
      # @return [Object] the client
      # @raise [ArgumentError] if the resource has no client
      def client!
        client || raise(ArgumentError, "#{self.class} has no client")
      end

      # Resolve a referenced resource through the identity map of its response
      # @api private
      # @param klass [Class] the resource class
      # @param id [String, nil] the identifier
      # @return [Resource, nil] the resource or nil if the identifier is missing
      def resolve(klass, id)
        includes.resolve(klass, id, client:) unless id.nil?
      end

      # Build a cursor over a collection endpoint scoped to this resource
      # @api private
      # @param klass [Class] the resource class of the items
      # @param path [String] the endpoint path
      # @param max_results [Integer] the maximum number of items per page
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] the cursor
      def cursor(klass, path, max_results:, **params)
        defaults = {max_results:} #: Hash[Symbol, untyped]
        Cursor.new(klass, client: client!, path:, params: defaults.merge(params))
      end
    end
  end
end
