# frozen_string_literal: true

require "x/core"
require_relative "errors"
require_relative "utils"

module X
  module Objects
    # Class methods that look resources up one at a time, extended into each resource class the API can look up
    #
    # A resource the API offers no lookup of, such as a poll or a place, does not extend it, and so answers none of
    # its methods, rather than answer them only to raise. BatchFinders includes it for a resource the API can also
    # look up many at a time.
    #
    # Internal to x-objects: the methods it gives a resource class, such as X::Post.find, are public API, but the module
    # is only how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module Finders
      # Look up a resource by identifier
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier, or a resource of this class
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if it was not found
      # @raise [ArgumentError] if the identifier is not one, or is a resource of another class, before a request
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Look up a post by identifier
      #   X::Post.find(1234567890, client: client)
      def find(id, client:, **params, &) = lookup("#{endpoint!}/#{Utils.id_of(id, self)}", client:, **params, &)

      # Look up a resource by identifier, which must exist
      #
      # The error it raises names the identifier looked up, whether the identifier or a resource was given.
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier, or a resource of this class
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource] the resource
      # @raise [ArgumentError] if the identifier is not one, or is a resource of another class, before a request
      # @raise [MissingResource] if the resource was not found
      # @example Look up a post by identifier
      #   X::Post.find!(1234567890, client: client)
      def find!(id, client:, **params)
        problems = [] #: Array[Problem]
        find(id, client:, **params) { |problem| problems << problem } || raise(MissingResource.new("Could not find #{self} #{Utils.id_from(id, self)}", problems:))
      end

      # Fetch a single resource from an endpoint
      #
      # Internal to x-objects: the finders and hydrate call it with the path of an endpoint, which names the API's
      # own resources and can change within 1.x as the API does.
      #
      # @api private
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if the response has no data
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch the authenticated user
      #   X::User.__send__(:lookup, "users/me", client: client)
      def lookup(path, client:, **params, &)
        query = Utils.merge_params(default_params, params)
        resource_built_from(reporting(get(path, client:, query:), &), client:, hydrated: fully_requested_by?(query), query:)
      end

      # Fetch a list of resources from an endpoint without paginating
      #
      # Internal to x-objects: the batch lookups call it with the path of an endpoint, which names the API's own
      # resources and can change within 1.x as the API does.
      #
      # @api private
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Array<Resource>] the resources
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch users by username
      #   X::User.__send__(:lookup_all, "users/by", client: client, usernames: ["sferik", "gem"])
      def lookup_all(path, client:, **params, &)
        query = Utils.merge_params(default_params, params)
        collection_built_from(reporting(get(path, client:, query:), &), client:, hydrated: fully_requested_by?(query), query:)
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
      #   X::User.__send__(:client_for, client) # => client
      def client_for(client) = client

      private :lookup, :lookup_all, :client_for

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
