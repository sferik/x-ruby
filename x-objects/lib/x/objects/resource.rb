# frozen_string_literal: true

require "json"
require "x/core"
require_relative "abstract_class"
require_relative "attributes"
require_relative "published_count"
require_relative "errors"
require_relative "identity"
require_relative "includes"
require_relative "marshalling"
require_relative "memo"
require_relative "serialization"
require_relative "utils"

module X
  module Objects
    # Base class for immutable API resources with identity, references, and hydration
    #
    # A reader of an object the API nests in a resource, or of a list of them, such as the entities, urls,
    # public_metrics, edit_controls, attachments, and withheld of a post, the variants of media, the options of a poll,
    # or the subscription and affiliation of a user, returns it as the API sends it: a frozen Hash keyed by String, or
    # an Array of them. Each returns that throughout 1.x. A reader that returns an object, as the matching_rules of a
    # post and the topics of a space do, is only ever added under a new name, never in place of one of these.
    #
    # @api public
    class ::X::Resource
      extend AbstractClass
      extend Attributes
      include PublishedCount
      include Identity
      include Serialization
      include Marshalling

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
      # @return [Objects::Includes] the identity map
      attr_reader :includes
      private :includes

      class << self
        # The API endpoint used to look up this resource by identifier
        #
        # @api private
        # @return [String, nil] the endpoint or nil if the resource cannot be looked up
        # @example Get the endpoint
        #   X::User.__send__(:endpoint) # => "users"
        def endpoint
        end

        # The attribute holding the identifier
        #
        # @api private
        # @return [String] the identifier key
        # @example Get the identifier key
        #   X::Media.__send__(:id_key) # => "media_key"
        def id_key = "id"

        # The type of the identifier, integer unless it is not a number
        #
        # @api private
        # @return [Symbol] integer, or raw for an identifier that is not a number
        # @example Get the identifier type
        #   X::Space.__send__(:id_type) # => :raw
        def id_type = :integer

        # The key under which this resource appears in the includes of a response
        #
        # @api private
        # @return [String, nil] the includes key or nil if the resource is never expanded
        # @example Get the includes key
        #   X::User.__send__(:includes_key) # => "users"
        def includes_key
        end

        # The query parameter that selects the fields of this resource
        #
        # @api private
        # @return [String, nil] the fields parameter or nil if the resource has no fields parameter
        # @example Get the fields parameter
        #   X::User.__send__(:fields_key) # => "user.fields"
        def fields_key
        end

        # Build a resource from an identifier, or from a resource, without a request
        #
        # @api public
        # @param id [String, Integer, Resource] the identifier, or a resource of this class, whose identifier is taken
        # @param client [Object, nil] the client used to fetch the resource and its references
        # @return [Resource] a stub that hydrates to the full resource
        # @raise [ArgumentError] if the identifier is not a number, for a resource whose identifiers are numbers, or the
        #   resource is of another class
        # @example Page through the followers of a user without looking the user up
        #   X::User.from_id(7505382, client: client).followers
        def from_id(id, client: nil) = from_id_in_batch(id, client:)

        # Build a stub that hydrates with the stubs of a batch, in one lookup for them all
        #
        # Internal to x-objects: a cursor that reads nothing but identifiers builds its stubs with it, and it takes a
        # Batch, which is internal too.
        #
        # @api private
        # @param id [String, Integer, Resource] the identifier, or a resource of this class, whose identifier is taken
        # @param client [Object, nil] the client used to fetch the resource and its references
        # @param batch [Objects::Batch, nil] the batch the stub hydrates with
        # @return [Resource] a stub that hydrates to the full resource
        # @raise [ArgumentError] if the identifier is not a number, for a resource whose identifiers are numbers, or the
        #   resource is of another class
        # @example Build the stub of a page of followers
        #   X::User.__send__(:from_id_in_batch, 7505382, client: client, batch: batch)
        def from_id_in_batch(id, client:, batch: nil) = build({id_key => Utils.id_from(id, self)}, client:, batch:)

        # Build a resource with the internals new keeps to itself
        #
        # Internal to x-objects: a response builds its resources over the identity map of its includes, and a cursor
        # its stubs over a Batch, both of which are internal, so new takes neither.
        #
        # @api private
        # @param attrs [Hash] the attributes, which must include the identifier
        # @param client [Object, nil] the client used to fetch references
        # @param includes [Objects::Includes] the identity map of the response the resource came from
        # @param hydrated [Boolean] whether the resource holds every requested field
        # @param batch [Objects::Batch, nil] the batch this stub hydrates with, in one lookup for every stub of the batch
        # @return [Resource] a new resource
        # @raise [ArgumentError] if the attributes do not include the identifier, or the identifier is not one
        # @example Build a post over the includes of its response
        #   X::Post.__send__(:build, {"id" => "1", "author_id" => "9"}, client: client, includes: includes)
        def build(attrs, client: nil, includes: Includes.new, hydrated: false, batch: nil)
          allocate.tap { |resource| resource.__send__(:setup, attrs, client:, includes:, hydrated:, batch:) }
        end

        # The default query parameters requesting every field and expansion
        #
        # They are built from the FIELDS and EXPANSIONS of the classes they name, which a minor release may add to; see
        # {Resource#hydrated?}.
        #
        # @api public
        # @return [Hash{String => Array<String>}] the default query parameters
        # @example Get the default parameters
        #   X::User.default_params
        def default_params = {}

        # Check whether a request asks for every default field and expansion
        #
        # A request that overrides a default parameter to leave out a field or an expansion it names builds resources
        # that are not hydrated, so that hydrate fetches the full resource rather than return one that lacks fields. A
        # request that asks for every one of them, in any order, and for more besides, such as non_public_metrics, is
        # hydrated, so hydrate returns the resource it built, which holds the fields it added, rather than fetch one
        # that lacks them.
        #
        # @api private
        # @param query [Hash{String => Object}] the query parameters of the request, merged over the defaults
        # @return [Boolean] true if every default parameter asks for every value it asks for by default
        # @example Check a request that asks for the name of a user alone
        #   X::User.__send__(:fully_requested_by?, "user.fields" => "name") # => false
        def fully_requested_by?(query)
          Utils.query(default_params).all? { |key, value| (value.split(",") - query[key].to_s.split(",")).empty? }
        end

        # The query parameter a batch lookup takes the identifiers in
        #
        # @api private
        # @return [Symbol] the parameter name
        # @example Get the parameter of a batch lookup of media
        #   X::Media.__send__(:batch_key) # => :media_keys
        def batch_key = :ids

        # The lookup endpoint, which must exist
        #
        # @api private
        # @return [String] the endpoint
        # @raise [UnsupportedOperation] if the resource cannot be looked up by identifier
        # @example Get the lookup endpoint
        #   X::User.__send__(:endpoint!) # => "users"
        def endpoint! = endpoint || raise(UnsupportedOperation, "#{self} cannot be fetched by #{id_key}")

        # Build the resource a request that creates one returned, which must hold it
        #
        # The API answers a request that creates a resource with the resource, so a successful response without one
        # created nothing the caller can read, and raises, holding the problems the response reported, as current!
        # raises for a users/me that returns no user, rather than return nil, which the caller would read as the
        # resource.
        #
        # Internal to the object layer, as resource_from_response is.
        #
        # @api private
        # @param body [Hash, nil] the parsed response body
        # @param request [String] the method and path of the request, which the message names
        # @param client [Object] the client used to make the request
        # @return [Resource] the resource
        # @raise [MissingResource] if the response holds no resource
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one
        # @example Build the post a request created
        #   X::Post.__send__(:created_from_response, {"data" => {"id" => "1"}}, "POST tweets", client: client)
        def created_from_response(body, request, client:) = resource_from_response(body, client:) || raise(MissingResource.new("#{request} returned no #{self}", problems: Problem.all_from(body)))

        private :endpoint, :id_key, :id_type, :includes_key, :fields_key, :from_id_in_batch, :build, :fully_requested_by?, :batch_key, :endpoint!, :created_from_response

        # Build the resource or resources a response holds
        #
        # A response whose data is an object builds one resource, and one whose data is an array builds a Page of one
        # for each element, which holds the meta of the response, such as its next_token, and the problems it
        # reported. A list the API finds empty holds no data, only a meta, which may still name the token of a page
        # after it, so a response with a meta and no data builds an empty Page. A lookup of several resources by their
        # identifiers, such as users?ids=, that finds none of them holds no data and no meta, only a problem for each,
        # which names the ids, media_keys, or usernames parameter, so it builds an empty Page of those problems, as a
        # lookup that finds some of them builds a Page of those it found. A client calls this when a resource class is
        # the object_class of a request.
        # A later version of x-core may pass it keywords of its own, which are ignored, as X::Client asks of
        # what it calls from_response on.
        #
        # A response holds only the fields its request asked for, so what this builds is not hydrated
        # unless told otherwise, and hydrate fetches the full resource.
        #
        # @api public
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Resource, Page, nil] the resource, or the page of resources, or nil if the response has no data, no
        #   meta, and no problem of a lookup of several
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one
        # @example Build a user from a response
        #   X::User.from_response({"data" => {"id" => "7505382"}}, client: client)
        # @example Build users from a client request, and read the token of the next page
        #   client.get("users/7505382/blocking", object_class: X::User).next_token
        def from_response(body, client:, hydrated: false, **)
          return collection_from_response(body, client:, hydrated:) if Page.__send__(:list?, body.to_h)

          resource_from_response(body, client:, hydrated:)
        end

        # Build a resource from a response with a single data object
        #
        # A line of the filtered stream holds the rules its post matched beside its data, as matching_rules, which the
        # resource keeps among its attributes, where X::Post#matching_rules reads them.
        #
        # Internal to the object layer: from_response, which a client calls, builds what a response holds, and takes
        # the keywords a later version of x-core may pass it, where this does not.
        #
        # @api private
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Resource, nil] the resource or nil if the response has no data
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one
        # @example Build a user from a response
        #   X::User.__send__(:resource_from_response, {"data" => {"id" => "7505382"}}, client: client)
        private def resource_from_response(body, client:, hydrated: false) = resource_built_from(body, client:, hydrated:, query: nil)

        # Build resources from a response with a data array
        #
        # Internal to the object layer, as resource_from_response is.
        #
        # @api private
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @return [Page] the page of resources, with the meta and problems of the response
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one,
        #   or a meta that is not an object
        # @example Build users from a response
        #   X::User.__send__(:collection_from_response, {"data" => [{"id" => "7505382"}]}, client: client)
        private def collection_from_response(body, client:, hydrated: false) = Page.new(collection_built_from(body, client:, hydrated:, query: nil), meta: Page.__send__(:meta_of, body), problems: Problem.all_from(body))

        # Build a resource from a response, knowing the query of its request
        #
        # Internal to the object layer: the query, which the lookups and cursors of the object layer know, tells whether
        # the resources the response included are hydrated, and which of the fields that tells by can change within 1.x.
        #
        # @api private
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @param query [Hash{String => Object}, nil] the query parameters of the request, merged over the defaults,
        #   which tell whether the resources it included are hydrated, or nil if they are not known
        # @return [Resource, nil] the resource or nil if the response has no data
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one
        private def resource_built_from(body, client:, hydrated:, query:)
          body = body.to_h
          data = body["data"]
          return unless data.is_a?(Hash)

          built(data.merge(body.slice("matching_rules")), client:, includes: Includes.new(body["includes"], problems: Problem.all_from(body), query:), hydrated:)
        end

        # Build resources from a response, knowing the query of its request
        #
        # Internal to the object layer, as resource_built_from is.
        #
        # @api private
        # @param body [Hash, nil] the parsed response body
        # @param client [Object] the client used to make the request
        # @param hydrated [Boolean] whether the response holds every field the object layer requests
        # @param query [Hash{String => Object}, nil] the query parameters of the request, merged over the defaults,
        #   which tell whether the resources it included are hydrated, or nil if they are not known
        # @return [Array<Resource>] the resources
        # @raise [InvalidAttribute] if the response holds a resource without an identifier, or with one that is not one
        private def collection_built_from(body, client:, hydrated:, query:)
          body = body.to_h
          data = Array.try_convert(body["data"])
          includes = Includes.new(body["includes"], problems: Problem.all_from(body), query:)
          Array(data).map { |attrs| built(attrs, client:, includes:, hydrated:) }.freeze
        end

        # Build a resource a response holds, whose identifier must be one
        # @api private
        # @param attrs [Hash] the attributes the response holds
        # @param client [Object, nil] the client used to fetch references
        # @param includes [Objects::Includes] the identity map of the response
        # @param hydrated [Boolean] whether the resource holds every requested field
        # @return [Resource] the resource
        # @raise [InvalidAttribute] if the attributes hold no identifier, or hold one that is not one
        private def built(attrs, client:, includes:, hydrated:) = Utils.read("#{self}##{id_key}", Hash.try_convert(attrs)&.[](id_key)) { build(attrs, client:, includes:, hydrated:) }
      end
      private_class_method(*AbstractClass::BUILDERS)

      # Initialize a new immutable resource
      #
      # @api public
      # @param attrs [Hash] the attributes, which must include the identifier
      # @param client [Object, nil] the client used to fetch references
      # @param hydrated [Boolean] whether the resource holds every requested field
      # @return [Resource] a new resource
      # @raise [ArgumentError] if the attributes are not a Hash, do not include the identifier, or hold an identifier that
      #   is not one
      # @example Create a user from attributes
      #   X::User.new({"id" => "7505382", "username" => "sferik"}, client: client)
      def initialize(attrs, client: nil, hydrated: false) = setup(Utils.attributes!(attrs), client:, hydrated:)

      # The identifier
      #
      # @api public
      # @return [Integer, String] the identifier, an Integer unless the resource's identifiers are not numbers
      # @example Get the identifier
      #   user.id # => 7505382
      def id
        Attributes::CONVERTERS.fetch(self.class.__send__(:id_type)).call(attrs.fetch(self.class.__send__(:id_key)))
      end

      # Check whether the resource holds every field the object layer requests
      #
      # A resource is hydrated when it was the subject of a response to a request that asked for every default field
      # and expansion, whether or not it asked for more. A stub, a reference a response included, and a resource looked
      # up with parameters that leave out some of those defaults are not, so hydrate fetches the full resource.
      #
      # The defaults are the FIELDS and EXPANSIONS of each class, which a minor release may add to as the API adds
      # fields and expansions, so that a lookup with the defaults asks for them too. A resource looked up with a list
      # of its own, even one that named every field of the release it was written for, then leaves out what was added,
      # so it is no longer hydrated, and hydrate costs a lookup of the full resource that the same code did not pay
      # before. To ask for more than the defaults, add to what default_params gives rather than list every value.
      #
      # @api public
      # @return [Boolean] true if the resource holds every field the object layer requests
      # @example Check whether a referenced user is hydrated
      #   post.author.hydrated? # => false
      def hydrated?
        @hydrated
      end

      # The problems the API reported about this resource in the response it came from
      #
      # A problem is about the resource when the identifier it names, as its resource_id or its value, is the
      # identifier of the resource or of one the resource refers to directly, such as the author of a post, or the
      # pinned post of a user, so each post of a page reports that its own author no longer exists, and none reports
      # it of another. A problem that names no identifier could be about any resource of the response, so every one
      # of them reports it. The page of a cursor reports every problem of its response, as a finder yields them.
      #
      # @api public
      # @return [Array<Problem>] the problems, such as expansions whose resources no longer exist
      # @example Check whether a user's pinned post still exists
      #   client.current_user!.problems.select(&:not_found?)
      def problems = includes.problems_about([id, *self.class.__send__(:referenced_ids, attrs)])

      # Check whether the resource holds nothing but its identifier
      #
      # A reference the response did not expand is a stub, and so is a resource built with from_id.
      #
      # @api public
      # @return [Boolean] true if the resource holds only its identifier
      # @example Check whether the author of a post was included in the response
      #   post.author.stub? # => false
      def stub? = attrs.keys.eql?([self.class.__send__(:id_key)])

      # Fetch the full resource, memoizing the result
      #
      # Each resource that is not hydrated costs a request of its own, so hydrate many resources, such as the authors
      # of the posts of a page, with the hydrate_all of their class, which looks them up a hundred at a time, rather
      # than call hydrate on each.
      #
      # @api public
      # @return [Resource, nil] the full resource or nil if it no longer exists
      # @raise [UnsupportedOperation] if the resource cannot be looked up by identifier, as a poll or a place cannot
      # @raise [MissingClient] if the resource has no client
      # @example Fetch the full user a stub names
      #   X::User.from_id(7_505_382, client: client).hydrate.description
      # @example Fetch the full authors of many posts in batches, rather than a request for each
      #   X::User.hydrate_all(posts.map(&:author), client: client).map(&:description)
      def hydrate
        @memo.fetch { hydrated? ? self : fetch }
      end

      # Fetch the full resource again, replacing the memoized result
      #
      # A stub that hydrates together with the others of its page looks itself up on its own, rather than read what
      # the lookup of the page found.
      #
      # @api public
      # @return [Resource, nil] the fresh resource or nil if it no longer exists
      # @raise [UnsupportedOperation] if the resource cannot be looked up by identifier, as a poll or a place cannot
      # @raise [MissingClient] if the resource has no client
      # @example Refresh a user's follower count
      #   user.refresh.followers_count
      def refresh
        @memo.store(look_up)
      end

      # Summarize the resource for the console
      #
      # @api public
      # @return [String] the class name and attributes
      # @example Inspect a user
      #   user.inspect # => #<X::User id="7505382" username="sferik">
      def inspect = "#<#{self.class} #{attrs.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")}>"

      private

      # Set the attributes and internals of a new resource, and freeze it
      # @api private
      # @param attrs [Hash] the attributes, which must include the identifier
      # @param client [Object, nil] the client used to fetch references
      # @param hydrated [Boolean] whether the resource holds every requested field
      # @param includes [Objects::Includes] the identity map of the response the resource came from
      # @param batch [Objects::Batch, nil] the batch this stub hydrates with
      # @return [void]
      # @raise [ArgumentError] if the attributes do not include the identifier, or the identifier is not one
      def setup(attrs, client:, hydrated:, includes: Includes.new, batch: nil)
        @attrs = Utils.deep_freeze(attrs)
        identify
        @client, @includes, @hydrated, @batch = client, includes, hydrated, batch
        @memo = Memo.new
        freeze
      end

      # Store the full resource a lookup of many found, so hydrate reads it
      #
      # Internal to the object layer: hydrate_all calls it with __send__, since a caller that stored another
      # resource would change what a frozen resource hydrates to.
      #
      # @api private
      # @param resource [Resource, nil] the full resource, or nil if it no longer exists
      # @return [Resource, nil] the resource that was stored
      def hydrated_with(resource) = @memo.store(resource)

      # Check whether hydrate would return what it stored, at the cost of no request
      #
      # Internal to the object layer: hydrate_all calls it with __send__, so that it looks up no resource that a
      # lookup of many, or hydrate, already found.
      #
      # @api private
      # @return [Boolean] true if hydrate or a lookup of many stored the full resource, or that it no longer exists
      def hydration_stored? = @memo.stored?

      # Read the identifier once, at the point the resource is made
      #
      # Attributes that hold no identifier, or hold one the API could not have given, would otherwise raise from a
      # reader, an equality test, or a Hash the resource is a key of, far from where they were written.
      #
      # @api private
      # @return [String] the identifier
      # @raise [ArgumentError] if the attributes hold no identifier, or hold one that is not one
      # @example Refuse a user whose identifier is not a number
      #   X::User.new({"id" => "abc"})
      def identify
        key = self.class.__send__(:id_key)
        value = attrs[key]
        raise ArgumentError, "#{self.class} requires #{key}" if value.nil?

        Utils.id_of(value, self.class)
      end

      # Fetch the full resource from the API, in the lookup of its batch if it has one
      # @api private
      # @return [Resource, nil] the full resource or nil if it no longer exists
      def fetch
        batch = @batch
        batch.nil? ? look_up : batch.fetch(id)
      end

      # Look the full resource up on its own
      # @api private
      # @return [Resource, nil] the full resource or nil if it no longer exists
      def look_up = self.class.__send__(:lookup, "#{self.class.__send__(:endpoint!)}/#{id}", client: client!)

      # The client, which must exist
      # @api private
      # @return [Object] the client
      # @raise [MissingClient] if the resource has no client
      def client!
        client || raise(MissingClient, "#{self.class} has no client")
      end

      # Resolve a referenced resource through the identity map of its response
      # @api private
      # @param klass [Class] the resource class
      # @param id [String, nil] the identifier
      # @return [Resource, nil] the resource or nil if the identifier is missing
      # @raise [InvalidAttribute] if the identifier is not one
      def resolve(klass, id)
        Utils.read("The reference of #{self.class} to #{klass}", id) { includes.resolve(klass, id, client:) } unless id.nil?
      end

      # Build a cursor over a collection endpoint scoped to this resource
      # @api private
      # @param klass [Class] the resource class of the items
      # @param path [String] the endpoint path
      # @param max_results [Integer, nil] the maximum number of items per page, or nil for an endpoint without pages
      # @param min_results [Integer] the smallest page the endpoint accepts
      # @param total [Symbol, nil] the attribute holding the number of resources the API publishes
      # @param app_only [Boolean] whether the endpoint takes app-only authentication, as a space endpoint does, so
      #   the pages are fetched with the app-only client of this resource's client
      # @param ids_only [Boolean] whether the endpoint gives the resources by their identifiers alone, and takes none of
      #   their fields, so the pages ask for none, and read stubs
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Cursor] the cursor
      def cursor(klass, path, max_results:, min_results: 1, total: nil, app_only: false, ids_only: false, **params)
        defaults = {max_results:} #: Hash[Symbol, untyped]
        Cursor.__send__(:build, klass, path, client: client!, params: defaults.merge(params), min_results:, app_only:, total: counter(total), ids_only:)
      end
    end
  end
end
