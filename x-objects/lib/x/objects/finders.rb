# frozen_string_literal: true

require_relative "errors"
require_relative "parallel"
require "x/core/problem"
require_relative "utils"

module X
  module Objects
    # Class methods that look resources up, extended into every resource class
    # @api public
    module Finders
      # Maximum number of identifiers accepted by a batch lookup endpoint
      MAX_BATCH_SIZE = 100

      # Default number of batch lookups a request makes at once, which matches the chunks an upload sends at once
      DEFAULT_CONCURRENCY = 4

      # The message of the error raised for a concurrency that would look nothing up
      INVALID_CONCURRENCY = "concurrency must be an Integer of at least 1, not %s"
      private_constant :INVALID_CONCURRENCY

      # The message of the error raised for a batch lookup of a resource the API offers none for
      NO_BATCH_LOOKUP = "%s cannot be fetched in batches; look %d of them up one at a time"
      private_constant :NO_BATCH_LOOKUP

      # Look up a resource by identifier
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if it was not found
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Look up a post by identifier
      #   X::Post.find(1234567890, client: client)
      def find(id, client:, **params, &) = lookup("#{endpoint!}/#{Utils.id_of(id, raw: id_type.eql?(:raw))}", client:, **params, &)

      # Look up a resource by identifier, which must exist
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource] the resource
      # @raise [MissingResource] if the resource was not found
      # @example Look up a post by identifier
      #   X::Post.find!(1234567890, client: client)
      def find!(id, client:, **params)
        problems = [] #: Array[Problem]
        find(id, client:, **params) { |problem| problems << problem } || raise(MissingResource.new("Could not find #{self} #{id}", problems:))
      end

      # Replace the resources that are not hydrated with the full resources
      #
      # A resource that hydrate would look up is looked up, which is a stub and also a resource a response included
      # without every field, so what comes back is hydrated throughout. A resource that was not found is dropped, and
      # a hydrated resource is kept as it is. Resources that are all hydrated need no lookup, so they are returned
      # even for a resource that cannot be looked up in batches. What was found is stored in each original, so
      # hydrating one of them afterwards costs no request.
      #
      # @api public
      # @param resources [Array<Resource>] the resources, some of which may not be hydrated
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batch lookups made at once, which must be at least one
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources, in order, with the ones that were not hydrated replaced
      # @raise [ArgumentError] if the concurrency is less than one
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Expand the authors a search did not include
      #   X::User.hydrate_all(posts.map(&:author), client: client)
      def hydrate_all(resources, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        partial = resources.reject(&:hydrated?)
        return resources.dup if partial.empty?

        found = find_all(partial, client:, concurrency:, **params, &).to_h { |resource| [resource.id, resource] }
        resources.filter_map { |resource| resource.hydrated? ? resource : resource.__send__(:hydrated_with, found[resource.id]) }
      end

      # Look up many resources by identifier, in parallel batches, once each
      #
      # @api public
      # @param ids [Array<String, Integer, Resource>] the identifiers
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; each is a
      #   request of up to MAX_BATCH_SIZE identifiers, so a lower number spends a rate limit more slowly
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources that were found
      # @raise [ArgumentError] if the concurrency is less than one
      # @raise [UnsupportedOperation] if the API offers no batch lookup of the resource, as it offers none for
      #   communities, lists, or direct message events, which are looked up one at a time
      # @yieldparam problem [Problem] each problem the API reported, such as an identifier that was not found
      # @example Look up many posts by identifier, reporting the ones that were not found
      #   X::Post.find_all([1234567890, 1234567891], client: client) { |problem| warn problem.detail }
      # @example Look up many posts one batch at a time, to spend a rate limit more slowly
      #   X::Post.find_all(ids, client: client, concurrency: 1)
      def find_all(ids, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        raise UnsupportedOperation, format(NO_BATCH_LOOKUP, self, ids.size) unless batchable?

        lookup_in_batches(endpoint!, batch_key, ids.map { |id| Utils.id_of(id, raw: id_type.eql?(:raw)) }, client:, concurrency:, **params, &)
      end

      # Fetch a single resource from an endpoint
      #
      # @api public
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if the response has no data
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch the authenticated user
      #   X::User.lookup("users/me", client: client)
      def lookup(path, client:, **params, &)
        query = Utils.merge_params(default_params, params)
        resource_from_response(reporting(get(path, client:, query:), &), client:, hydrated: fully_requested_by?(query))
      end

      # Fetch a list of resources from an endpoint without paginating
      #
      # @api public
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch users by username
      #   X::User.lookup_all("users/by", client: client, usernames: ["sferik", "gem"])
      def lookup_all(path, client:, **params, &)
        query = Utils.merge_params(default_params, params)
        collection_from_response(reporting(get(path, client:, query:), &), client:, hydrated: fully_requested_by?(query))
      end

      # The client a lookup of this resource makes its requests with
      #
      # Most endpoints take the client as it is, and one that refuses the credentials a client signs with, such as the
      # space endpoints, which refuse OAuth 1.0a, replaces it with a client that authenticates as the app.
      #
      # @api private
      # @param client [Object] the client the lookup was given
      # @return [Object] the client the request is made with
      # @example Get the client a user lookup requests with
      #   X::User.client_for(client) # => client
      def client_for(client) = client

      private

      # Request an endpoint
      # @api private
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param query [Hash] the query parameters, merged over the default parameters
      # @return [Hash, nil] the parsed response body
      def get(path, client:, query:)
        client_for(client).get(Utils.path(path, query), **Utils::JSON_CLASSES)
      end

      # Look up values in parallel batches, asking for each value once
      # @api private
      # @param path [String] the batch lookup endpoint path
      # @param key [Symbol] the query parameter the values go in, such as ids or usernames
      # @param values [Array<String>] the values
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources that were found
      # @raise [ArgumentError] if the concurrency is less than one
      # @yieldparam problem [Problem] each problem the responses reported
      def lookup_in_batches(path, key, values, client:, concurrency:, **params, &)
        raise ArgumentError, format(INVALID_CONCURRENCY, concurrency) unless concurrency.integer? && concurrency.positive?

        query = Utils.merge_params(default_params, params)
        bodies = Parallel.map(values.uniq.each_slice(MAX_BATCH_SIZE), concurrency:) { |batch| get(path, client:, query: query.merge(Utils.query(key => batch))) }
        bodies.flat_map { |body| collection_from_response(reporting(body, &), client:, hydrated: fully_requested_by?(query)) }
      end

      # Pass the problems a response body reports to a block, if there is one
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @return [Hash, nil] the body
      # @yieldparam problem [Problem] each problem the body reports
      def reporting(body)
        Problem.all_from(body).each { |problem| yield problem } if block_given?
        body
      end
    end
  end
end
