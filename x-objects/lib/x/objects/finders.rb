require_relative "errors"
require_relative "parallel"
require_relative "problem"
require_relative "utils"

module X
  module Objects
    # Class methods that look resources up, extended into every resource class
    # @api public
    module Finders
      # Maximum number of identifiers accepted by a batch lookup endpoint
      MAX_BATCH_SIZE = 100

      # Look up a resource by identifier
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Resource, nil] the resource or nil if it was not found
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Look up a user by identifier
      #   X::User.find("7505382", client: client)
      def find(id, client:, **params, &) = lookup("#{endpoint!}/#{Utils.id_of(id)}", client:, **params, &)

      # Look up a resource by identifier, which must exist
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Resource] the resource
      # @raise [ResourceNotFound] if the resource was not found
      # @example Look up a user by identifier
      #   X::User.find!("7505382", client: client)
      def find!(id, client:, **params)
        problems = [] #: Array[Problem]
        find(id, client:, **params) { |problem| problems << problem } || raise(ResourceNotFound.new("Could not find #{self} #{id}", problems:))
      end

      # Replace the stubs among some resources with the full resources
      #
      # A stub whose resource was not found is dropped, and a resource that is not a stub is kept as it is.
      #
      # @api public
      # @param resources [Array<Resource>] the resources, some of which may be stubs
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Resource>] the resources, in order, with the stubs replaced
      # @yieldparam problem [Problem] each problem the API reported, such as a stub whose resource was not found
      # @example Expand the authors a search did not include
      #   X::User.hydrate_all(posts.map(&:author), client: client)
      def hydrate_all(resources, client:, **params, &)
        found = find_all(resources.select(&:stub?), client:, **params, &).to_h { |resource| [resource.id, resource] }
        resources.filter_map { |resource| resource.stub? ? found[resource.id] : resource }
      end

      # Look up many resources by identifier, in parallel batches, once each
      #
      # @api public
      # @param ids [Array<String, Integer, Resource>] the identifiers
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Resource>] the resources that were found
      # @yieldparam problem [Problem] each problem the API reported, such as an identifier that was not found
      # @example Look up many users by identifier, reporting the ones that were not found
      #   X::User.find_all(["7505382", "12"], client: client) { |problem| warn problem.detail }
      def find_all(ids, client:, **params, &)
        lookup_in_batches(endpoint!, :ids, ids.map { |id| Utils.id_of(id) }, client:, **params, &)
      end

      # Fetch a single resource from an endpoint
      #
      # @api public
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Resource, nil] the resource or nil if the response has no data
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch the authenticated user
      #   X::User.lookup("users/me", client: client)
      def lookup(path, client:, **params, &)
        resource_from_response(reporting(get(path, client:, params:), &), client:, hydrated: true)
      end

      # Fetch a list of resources from an endpoint without paginating
      #
      # @api public
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Resource>] the resources
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch users by username
      #   X::User.lookup_all("users/by", client: client, usernames: ["sferik", "gem"])
      def lookup_all(path, client:, **params, &)
        collection_from_response(reporting(get(path, client:, params:), &), client:, hydrated: true)
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

      # Look up values in parallel batches, asking for each value once
      # @api private
      # @param path [String] the batch lookup endpoint path
      # @param key [Symbol] the query parameter the values go in, such as ids or usernames
      # @param values [Array<String>] the values
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<Resource>] the resources that were found
      # @yieldparam problem [Problem] each problem the responses reported
      def lookup_in_batches(path, key, values, client:, **params, &)
        bodies = Parallel.map(values.uniq.each_slice(MAX_BATCH_SIZE)) { |batch| get(path, client:, params: {key => batch, **params}) }
        bodies.flat_map { |body| collection_from_response(reporting(body, &), client:, hydrated: true) }
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
