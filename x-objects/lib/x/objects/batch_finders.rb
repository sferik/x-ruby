# frozen_string_literal: true

require_relative "finders"
require_relative "parallel"
require_relative "utils"

module X
  module Objects
    # Class methods that look resources up many at a time, extended into each resource class the API can look up so
    #
    # A resource the API looks up only one at a time, such as a list, a community, or a direct message event, extends
    # Finders alone, and so answers neither find_all nor hydrate_all, rather than answer them only to raise.
    #
    # Internal to x-objects: the methods it gives a resource class, such as X::Post.find_all, are public API, but the
    # module is only how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module BatchFinders
      include Finders

      # Maximum number of identifiers accepted by a batch lookup endpoint
      MAX_BATCH_SIZE = 100

      # Default number of batch lookups a request makes at once, which matches the chunks an upload sends at once
      DEFAULT_CONCURRENCY = 4

      # The message of the error raised for a concurrency that would look nothing up
      INVALID_CONCURRENCY = "concurrency must be an Integer of at least 1, not %s"
      private_constant :INVALID_CONCURRENCY

      # The message of the error raised for resources to hydrate that are not of the class hydrating them
      FOREIGN_RESOURCE = "%s.hydrate_all hydrates %s resources, not %s"
      private_constant :FOREIGN_RESOURCE

      # Replace the resources that are not hydrated with the full resources
      #
      # A resource that hydrate would look up is looked up, which is a stub and also a resource a response included
      # without every field, so what comes back is hydrated throughout. A resource that was not found is dropped, as
      # is nil, which a reference to no resource reads as, such as the author of a post whose response named none,
      # and a hydrated resource is kept as it is, so resources that are all hydrated need no lookup. What was found is
      # stored in each original, so hydrating one of them afterwards costs no request, unless params override a
      # default field or expansion parameter: what such a lookup found is not the full resource, so it is returned
      # without being stored, and hydrating an original fetches the full resource. A resource that holds what hydrate
      # returns, because hydrate or an earlier hydrate_all stored it, is replaced with that, and looked up again by no
      # request, since the API bills each resource a lookup returns.
      #
      # @api public
      # @param resources [Array<Resource, nil>] the resources, some of which may not be hydrated, and some nil
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batch lookups made at once, which must be at least one
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources, in order, with the ones that were not hydrated replaced, frozen
      # @raise [ArgumentError] if the concurrency is less than one
      # @raise [ArgumentError] if a resource is not of this class, which a lookup of its identifier would find
      #   another resource for, before a request
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Look up every field of the authors of posts, the ones a search included among them
      #   X::User.hydrate_all(posts.map(&:author), client: client)
      # @example Expand only the authors a search did not include, which the API bills for alone
      #   X::User.hydrate_all(posts.filter_map(&:author).select(&:stub?), client: client)
      def hydrate_all(resources, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        resources = resources.compact
        validate_class!(resources)
        partial = resources.reject { |resource| settled?(resource) }
        replace = replacer(find_all(partial, client:, concurrency:, **params, &), params)
        resources.filter_map { |resource| settled?(resource) ? resource.hydrate : replace.call(resource) }.freeze
      end

      # Look up many resources by identifier, in parallel batches, once each
      #
      # The resources come back in the order of the identifiers they were asked for by, each once, whatever order
      # the batches were answered in.
      #
      # @api public
      # @param ids [Array<String, Integer, Resource>] the identifiers, or resources of this class
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; each is a
      #   request of up to MAX_BATCH_SIZE identifiers, so a lower number spends a rate limit more slowly
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources that were found, frozen
      # @raise [ArgumentError] if the concurrency is less than one
      # @raise [ArgumentError] if an identifier is not one, or is a resource of another class, before a request
      # @yieldparam problem [Problem] each problem the API reported, such as an identifier that was not found
      # @example Look up many posts by identifier, reporting the ones that were not found
      #   X::Post.find_all([1234567890, 1234567891], client: client) { |problem| warn problem.detail }
      # @example Look up many posts one batch at a time, to spend a rate limit more slowly
      #   X::Post.find_all(ids, client: client, concurrency: 1)
      def find_all(ids, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        ids = ids.map { |id| Utils.id_of(id, self) }
        in_order_of(lookup_in_batches(endpoint!, batch_key, ids, client:, concurrency:, **params, &), ids)
      end

      private

      # What replaces each resource that is not hydrated, from what a lookup found
      #
      # A lookup of every field found the full resource, which is stored in the original, as is a resource it did not
      # find. A lookup of some fields found what is returned in its place, and nothing is stored.
      #
      # @api private
      # @param found [Array<Resource>] the resources the lookup found
      # @param params [Hash] the query parameters the lookup was given, merged over the default parameters
      # @return [Proc] a callable passed a resource that is not hydrated, which returns what replaces it, or nil
      def replacer(found, params)
        by_id = found.to_h { |resource| [resource.id, resource] }
        return ->(resource) { by_id[resource.id] } unless fully_requested_by?(Utils.merge_params(default_params, params))

        ->(resource) { resource.__send__(:hydrated_with, by_id[resource.id]) }
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
      # @return [Array<Resource>] the resources that were found, in the order the batches were answered in
      # @raise [ArgumentError] if the concurrency is less than one
      # @yieldparam problem [Problem] each problem the responses reported
      def lookup_in_batches(path, key, values, client:, concurrency:, **params, &)
        validate_concurrency!(concurrency)
        query = Utils.merge_params(default_params, params)
        bodies = Parallel.map(values.uniq.each_slice(MAX_BATCH_SIZE), concurrency:) { |batch| get(path, client:, query: query.merge(Utils.query(key => batch))) }
        bodies.flat_map { |body| collection_from_response(reporting(body, &), client:, hydrated: fully_requested_by?(query)) }
      end

      # Order resources as the identifiers they were asked for by, each once
      #
      # An identifier is read as the resource reads its own, so that one asked for as a String of digits matches the
      # Integer of the resource.
      #
      # @api private
      # @param resources [Array<Resource>] the resources found
      # @param ids [Array<String>] the identifiers asked for
      # @return [Array<Resource>] the resources, in the order of the first identifier that matches each, frozen
      def in_order_of(resources, ids)
        convert = Attributes::CONVERTERS.fetch(id_type)
        by_id = resources.to_h { |resource| [resource.id, resource] }
        ids.filter_map { |id| by_id[convert.call(id)] }.uniq.freeze
      end

      # Check whether hydrating a resource costs no request
      # @api private
      # @param resource [Resource] the resource
      # @return [Boolean] true if the resource is hydrated, or holds what hydrate returns
      def settled?(resource) = resource.hydrated? || resource.__send__(:hydration_stored?)

      # Check that a number of batches to look up at once is an Integer of at least one
      #
      # Anything that is not an Integer, such as a String read from an environment variable, raises ArgumentError too,
      # rather than NoMethodError from the check.
      #
      # @api private
      # @param concurrency [Integer] the number of batches looked up at once
      # @return [void]
      # @raise [ArgumentError] if the concurrency is not an Integer, or is less than one
      def validate_concurrency!(concurrency)
        raise ArgumentError, format(INVALID_CONCURRENCY, concurrency.inspect) unless concurrency.instance_of?(Integer) && concurrency.positive?
      end

      # Check that resources to hydrate are of this class, whose endpoint looks them up
      # @api private
      # @param resources [Array<Resource>] the resources
      # @return [void]
      # @raise [ArgumentError] if a resource is not of this class
      def validate_class!(resources)
        foreign = resources.grep_v(self).first
        raise ArgumentError, format(FOREIGN_RESOURCE, self, self, foreign.class) unless foreign.nil?
      end
    end
  end
end
