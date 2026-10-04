# frozen_string_literal: true

require "x/core"
require_relative "errors"
require_relative "utils"

module X
  module Resources
    # Class methods that look resources up one at a time, extended into each resource class the API can look up
    #
    # A resource the API offers no lookup of, such as a poll or a place, does not extend it, and so answers none of
    # its methods, rather than answer them only to raise. BatchFinders includes it for a resource the API can also
    # look up many at a time.
    #
    # Internal to x-resources: the methods it gives a resource class, such as X::Post.find, are public API, but the module
    # is only how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api semipublic
    module Finders
      # Look up a resource by identifier
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier, or a resource of this class
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if it was not found, whether the API answers 200 with no data or a
      #   404 that reports the resource as not found
      # @raise [ArgumentError] if the identifier is not one, or is a resource of another class, before a request
      # @raise [X::NotFound] if the API answers any other 404, such as one from a client pointed at the wrong host or
      #   API version
      # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
      # @example Look up a post by identifier
      #   X::Post.find(1234567890, client: client)
      def find(id, client:, **params, &) = locate("#{endpoint!}/#{Utils.id_of(id, self)}", client:, **params, &)

      # Look up a resource by identifier, which must exist
      #
      # The error it raises names the identifier looked up, whether the identifier or a resource was given. Its cause
      # is the X::NotFound of a lookup the API answered with a 404 that reports the resource as not found.
      #
      # @api public
      # @param id [String, Integer, Resource] the identifier, or a resource of this class
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource] the resource
      # @raise [ArgumentError] if the identifier is not one, or is a resource of another class, before a request
      # @raise [MissingResource] if the resource was not found, whether the API answers 200 with no data or a 404 that
      #   reports the resource as not found
      # @raise [X::NotFound] if the API answers any other 404, such as one from a client pointed at the wrong host or
      #   API version
      # @example Look up a post by identifier
      #   X::Post.find!(1234567890, client: client)
      def find!(id, client:, **params)
        locate!("#{endpoint!}/#{Utils.id_of(id, self)}", Utils.id_from(id, self), client:, **params)
      end

      # Fetch a single resource from an endpoint
      #
      # Internal to x-resources: locate and the lookup of the authenticated user call it with the path of an endpoint,
      # which names the API's own resources and can change within 1.x as the API does. It raises the NotFound of a
      # 404, which only locate, whose path names one resource, reads as a resource that is missing, and only when the
      # 404 reports it so.
      #
      # Data that holds no identifier is no resource: X answers the lookup of a user that does not exist, when it asks
      # for a field the client may not read, such as parody for a client that authenticates as the app, with data that
      # holds only the defaults of the fields it may, and the errors of those it may not, but no identifier.
      #
      # @api private
      # @param path [String] the endpoint path
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if the response has no data, or data that holds no identifier
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch the authenticated user
      #   X::User.__send__(:lookup, "users/me", client: client)
      def lookup(path, client:, **params, &)
        query = Utils.merge_params(default_params, params)
        body = reporting(get(path, client:, query:), &)
        resource_built_from(body, client:, hydrated: fully_requested_by?(query), query:) unless resourceless?(body)
      end

      # Fetch the resource a path names, which may be missing
      #
      # Internal to x-resources: the finders and hydrate call it with a path that ends in the identifier or the username
      # of the resource, which they checked before building it. X documents both a 200 with no data and a 404 that
      # reports the resource as not found as its answer to the lookup of a resource that is deleted, suspended, or was
      # never there, so this reads the NotFound of the one as lookup reads the other: it finds nothing, and the block
      # is given the problems the body of the 404 named.
      #
      # Any other 404 raises as it is, as every other failure does, since it says nothing of the resource: one that
      # answers another request the client made for the lookup, such as the request for a token, or one whose body
      # reports no resource as not found, such as that of a client pointed at the wrong host or API version.
      #
      # @api private
      # @param path [String] the endpoint path, which ends in the identifier or the username of the resource
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource, nil] the resource or nil if the API answers a 404 that reports the resource as not found,
      #   or a response that holds no resource
      # @raise [X::NotFound] if the API answers any other 404
      # @yieldparam problem [Problem] each problem the API reported
      # @example Fetch a user that may not exist
      #   X::User.__send__(:locate, "users/7505382", client: client)
      def locate(path, client:, **params, &)
        lookup(path, client:, **params, &)
      rescue X::NotFound => e
        raise unless reports_missing?(e, path)

        e.problems.each { |problem| yield problem } if block_given?
        nil
      end

      # Fetch the resource a path names, which must exist
      #
      # Internal to x-resources: the finders that end in a bang call it with the path locate takes, and what the message
      # of the error names the resource by. The error holds the problems of the response, and, when the API answers
      # a 404 that reports the resource as not found, its cause is the NotFound that holds the response itself.
      #
      # @api private
      # @param path [String] the endpoint path, which ends in the identifier or the username of the resource
      # @param name [String] the identifier, or the username after an at sign, the message names the resource by
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters; one that overrides a default field
      #   or expansion parameter to leave some out builds resources that are not hydrated, so hydrate fetches the rest
      # @return [Resource] the resource
      # @raise [MissingResource] if the API answers a 404 that reports the resource as not found, or a response that
      #   holds no resource
      # @raise [X::NotFound] if the API answers any other 404
      # @example Fetch a user that must exist
      #   X::User.__send__(:locate!, "users/7505382", "7505382", client: client)
      def locate!(path, name, client:, **params)
        problems = [] #: Array[Problem]
        lookup(path, client:, **params) { |problem| problems << problem } || raise(missing(name, problems))
      rescue X::NotFound => e
        raise unless reports_missing?(e, path)

        raise missing(name, e.problems)
      end

      # Fetch a list of resources from an endpoint without paginating
      #
      # Internal to x-resources: the batch lookups call it with the path of an endpoint, which names the API's own
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

      private :lookup, :locate, :locate!, :lookup_all, :client_for

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

      # Build the resource a request that creates one returned, which must hold it
      #
      # The API answers a request that creates a resource with the resource, so a successful response without one
      # created nothing the caller can read, and raises, holding the problems the response reported, as current!
      # raises for a users/me that returns no user, rather than return nil, which the caller would read as the
      # resource. A response whose data holds no identifier holds no resource, as find reads it, so it raises too.
      #
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @param request [String] the method and path of the request, which the message names
      # @param client [Object] the client used to make the request
      # @return [Resource] the resource
      # @raise [MissingResource] if the response holds no resource, or data without an identifier
      # @raise [InvalidAttribute] if the response holds a resource with an identifier that is not one
      # @example Build the post a request created
      #   X::Post.__send__(:created_from_response, {"data" => {"id" => "1"}}, "POST tweets", client: client)
      def created_from_response(body, request, client:)
        raise MissingResource.new("#{request} returned no #{self}", problems: Problem.all_from(body)) if resourceless?(body)

        resource_built_from(body, client:, hydrated: false, query: nil) #: Resource
      end

      # The error of a resource a lookup did not find
      # @api private
      # @param name [String] the identifier, or the username after an at sign, the message names the resource by
      # @param problems [Array<Problem>] the problems the API reported
      # @return [MissingResource] the error, which names the class and the resource
      def missing(name, problems) = MissingResource.new("Could not find #{self} #{name}", problems:)

      # Whether a 404 reports the resource a lookup named as not found
      #
      # It does when it answers the lookup itself, a GET of a URI whose path ends in the path of the lookup, behind
      # whatever path the base URL of the client holds, and its body describes, or names among its errors, a problem
      # of the resource-not-found type. A NotFound that names no request, as one built without a URI does, is not
      # known to answer the lookup, so it reports nothing.
      #
      # @api private
      # @param error [X::NotFound] the error of the 404
      # @param path [String] the endpoint path of the lookup
      # @return [Boolean] true if the 404 answers the lookup and reports a resource as not found
      def reports_missing?(error, path)
        error.http_method.eql?(:get) && error.uri&.path.to_s.end_with?("/#{path}") &&
          [*error.problems, error.problem].compact.any?(&:not_found?)
      end

      # Whether a response body holds no resource
      #
      # It holds none when it holds no data, data that is no object, or an object with no identifier.
      #
      # @api private
      # @param body [Hash, nil] the parsed response body
      # @return [Boolean] true if the body holds no object with an identifier as its data
      def resourceless?(body) = Hash.try_convert(body.to_h["data"]).to_h[id_key].nil?

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
    private_constant :Finders
  end
end
