# frozen_string_literal: true

require_relative "../space"

module X
  module Resources
    module Lookups
      # Look up and search spaces, mixed into a client through API
      #
      # Internal to x-resources: X::Resources::API includes it, and its methods are public API of the client that
      # includes API, but the module is only how they are grouped, and some of them need the methods of another,
      # so include API rather than this module alone.
      #
      # @api semipublic
      module Spaces
        # Look up a space by identifier
        #
        # @api public
        # @param id [String, Integer, Space] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Space, nil] the space or nil if the space was not found
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up a space
        #   client.find_space("1DXxyRYNejbKM").title
        def find_space(id, **params, &)
          Space.find(id, client: self, **params, &)
        end

        # Look up a space by identifier, which must exist
        #
        # @api public
        # @param id [String, Integer, Space] the identifier
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Space] the space
        # @raise [MissingResource] if the space was not found
        # @example Look up a space
        #   client.find_space!("1DXxyRYNejbKM").title
        def find_space!(id, **params)
          Space.find!(id, client: self, **params)
        end

        # Look up many spaces by identifier, in parallel batches
        #
        # @api public
        # @param ids [Array<String, Integer, Space>] the identifiers
        # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Space>] the spaces that were found
        # @raise [ArgumentError] if the concurrency is less than one
        # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
        # @example Look up many spaces
        #   client.find_all_spaces(["1DXxyRYNejbKM", "1OwGWzarWnNKQ"]).map(&:title)
        def find_all_spaces(ids, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
          Space.find_all(ids, client: self, concurrency:, **params, &)
        end

        # Look up the live and scheduled spaces many users created, in parallel batches
        #
        # @api public
        # @param users [Array<User, String, Integer>] the users who created the spaces, or their identifiers
        # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
        # @param params [Hash] query parameters merged over the default parameters
        # @return [Array<Space>] the spaces, frozen, empty if the users created none
        # @raise [ArgumentError] if a user is not a user or the identifier of one, or the concurrency is less than
        #   one, before a request
        # @yieldparam problem [Problem] each problem the API reported
        # @example Print the live spaces a user created
        #   client.find_all_spaces_by_creator([7505382]).select { |space| space.state.eql?("live") }.map(&:title)
        def find_all_spaces_by_creator(users, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
          Space.find_all_by_creator(users, client: self, concurrency:, **params, &)
        end

        # Search spaces by their titles
        #
        # @api public
        # @param query [String] the search query
        # @param params [Hash] query parameters merged over the default parameters, such as state: live or scheduled
        # @return [Cursor] a cursor over the matching spaces
        # @example Print the live spaces about Ruby
        #   client.search_spaces("ruby", state: "live").each { |space| puts space.title }
        def search_spaces(query, **params)
          Space.search(query, client: self, **params)
        end
      end
    end
  end
end
