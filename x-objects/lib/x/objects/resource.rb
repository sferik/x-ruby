require_relative "attributes"
require_relative "errors"
require_relative "finders"
require_relative "identity"
require_relative "includes"
require_relative "memo"
require_relative "problem"
require_relative "utils"

module X
  module Objects
    # Base class for immutable API resources with identity, references, and hydration
    # @api public
    class Resource
      extend Attributes
      extend Finders
      include Identity

      # Maximum number of identifiers accepted by a batch lookup endpoint
      MAX_BATCH_SIZE = Finders::MAX_BATCH_SIZE

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
        def id_key = "id"

        # The type of the identifier, integer unless it is not a number
        #
        # @api public
        # @return [Symbol] integer, or raw for an identifier that is not a number
        # @example Get the identifier type
        #   X::Space.id_type # => :raw
        def id_type = :integer

        # The key under which this resource appears in the includes of a response
        #
        # @api public
        # @return [String, nil] the includes key or nil if the resource is never expanded
        # @example Get the includes key
        #   X::User.includes_key # => "users"
        def includes_key
        end

        # The query parameter that selects the fields of this resource
        #
        # @api public
        # @return [String, nil] the fields parameter or nil if the resource has no fields parameter
        # @example Get the fields parameter
        #   X::User.fields_key # => "user.fields"
        def fields_key
        end

        # Build a resource from an identifier, or from a resource, without a request
        #
        # @api public
        # @param id [String, Integer, Resource] the identifier, or a resource whose identifier is taken
        # @param client [Object, nil] the client used to fetch the resource and its references
        # @return [Resource] a stub that hydrates to the full resource
        # @example Page through the followers of a user without looking the user up
        #   X::User.from_id(7505382, client: client).followers
        def from_id(id, client: nil, batch: nil) = new({id_key => Utils.id_of(id)}, client:, batch:)

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
        def hydratable? = !endpoint.nil?

        # The lookup endpoint, which must exist
        #
        # @api public
        # @return [String] the endpoint
        # @raise [NotImplementedError] if the resource cannot be looked up by identifier
        # @example Get the lookup endpoint
        #   X::User.endpoint! # => "users"
        def endpoint! = endpoint || raise(NotImplementedError, "#{self} cannot be fetched by #{id_key}")

        # Build the resource or resources a response holds
        #
        # A response whose data is an object builds one resource, and one whose data is an array builds
        # one for each element. A client calls this when a resource class is the object_class of a request.
        #
        # A response holds only the fields its request asked for, so what this builds is not hydrated
        # unless told otherwise, and hydrate fetches the full resource.
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Resource, Array<Resource>, nil] the resource or resources, or nil if the response has no data
        # @example Build a user from a response
        #   X::User.from_response({"data" => {"id" => "7505382"}}, client: client)
        # @example Build users from a client request
        #   client.get("users/by?usernames=sferik,gem", object_class: X::User)
        def from_response(body, client:, hydrated: false)
          return collection_from_response(body, client:, hydrated:) if body.to_h["data"].is_a?(Array)

          resource_from_response(body, client:, hydrated:)
        end

        # Build a resource from a response with a single data object
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Resource, nil] the resource or nil if the response has no data
        # @example Build a user from a response
        #   X::User.resource_from_response({"data" => {"id" => "7505382"}}, client: client)
        def resource_from_response(body, client:, hydrated: false)
          body = body.to_h
          data = body["data"]
          return unless data.is_a?(Hash)

          new(data, client:, includes: Includes.new(body["includes"], problems: Problem.all_from(body)), hydrated:)
        end

        # Build resources from a response with a data array
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Array<Resource>] the resources
        # @example Build users from a response
        #   X::User.collection_from_response({"data" => [{"id" => "7505382"}]}, client: client)
        def collection_from_response(body, client:, hydrated: false)
          body = body.to_h
          data = body["data"]
          data = nil unless data.is_a?(Array)
          includes = Includes.new(body["includes"], problems: Problem.all_from(body))
          Array(data).map { |attrs| new(attrs, client:, includes:, hydrated:) }.freeze
        end
      end

      # Initialize a new immutable resource
      #
      # @api public
      # @param attrs [Hash] the attributes, which must include the identifier
      # @param client [Object, nil] the client used to fetch references
      # @param includes [Includes] the identity map of the response the resource came from
      # @param hydrated [Boolean] whether the resource holds every requested field
      # @param batch [Batch, nil] the batch this stub hydrates with, in one lookup for every stub of the batch
      # @return [Resource] a new resource
      # @raise [ArgumentError] if the attributes do not include the identifier
      # @example Create a user from attributes
      #   X::User.new({"id" => "7505382", "username" => "sferik"}, client: client)
      def initialize(attrs, client: nil, includes: Includes.new, hydrated: false, batch: nil)
        @attrs = Utils.deep_freeze(attrs)
        raise ArgumentError, "#{self.class} requires #{self.class.id_key}" if @attrs[self.class.id_key].nil?

        @client = client
        @includes = includes
        @hydrated = hydrated
        @batch = batch
        @memo = Memo.new
        freeze
      end

      # The identifier
      #
      # @api public
      # @return [Integer, String] the identifier, an Integer unless the resource's identifiers are not numbers
      # @example Get the identifier
      #   user.id # => 7505382
      def id
        Attributes::CONVERTERS.fetch(self.class.id_type).call(attrs.fetch(self.class.id_key))
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

      # The problems the API reported in the response this resource came from
      #
      # @api public
      # @return [Array<Problem>] the problems, such as expansions whose resources no longer exist
      # @example Check whether a user's pinned post still exists
      #   client.current_user.problems.select(&:not_found?)
      def problems = includes.problems

      # Check whether the resource holds nothing but its identifier
      #
      # A reference the response did not expand is a stub, and so is a resource built with from_id.
      #
      # @api public
      # @return [Boolean] true if the resource holds only its identifier
      # @example Check whether the author of a post was included in the response
      #   post.author.stub? # => false
      def stub? = attrs.keys.eql?([self.class.id_key])

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
      def fetch
        batch = @batch
        return batch.fetch(id) unless batch.nil?

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
      # @param max_results [Integer, nil] the maximum number of items per page, or nil for an endpoint without pages
      # @param min_results [Integer] the smallest page the endpoint accepts
      # @param total [Symbol, nil] the attribute holding the number of resources the API publishes
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] the cursor
      def cursor(klass, path, max_results:, min_results: 1, total: nil, **params)
        defaults = {max_results:} #: Hash[Symbol, untyped]
        Cursor.new(klass, path, client: client!, params: defaults.merge(params), min_results:, total: counter(total))
      end

      # A block reading the attribute holding the number the API publishes
      #
      # A resource without the attribute, such as a stub, is hydrated to read it, which costs one lookup rather than
      # paging through the collection.
      #
      # @api private
      # @param total [Symbol, nil] the attribute name, or nil if the API publishes no number
      # @return [Proc, nil] the block, or nil if the API publishes no number
      def counter(total)
        -> { public_send(total) || hydrate&.public_send(total) } unless total.nil?
      end
    end
  end
end
