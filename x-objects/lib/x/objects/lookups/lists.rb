# frozen_string_literal: true

require_relative "../list"

module X
  module Objects
    module Lookups
      # Look up lists, mixed into a client through API
      #
      # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api private
      module Lists
        # Look up a list by identifier
        #
        # @api public
        # @param id [String, Integer, List] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [List, nil] the list or nil if the list was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a list
        #   client.find_list(1234567890).name
        def find_list(id, **params, &)
          List.find(id, client: self, **params, &)
        end

        # Look up a list by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, List] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [List] the list
        # @raise [MissingResource] if the list was not found
        # @example Look up a list
        #   client.find_list!(1234567890).name
        def find_list!(id, **params)
          List.find!(id, client: self, **params)
        end
      end
    end
  end
end
