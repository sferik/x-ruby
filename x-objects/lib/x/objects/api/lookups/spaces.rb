# frozen_string_literal: true

require_relative "../../space"

module X
  module Objects
    module API
      module Lookups
        # Look up and search spaces, mixed into a client through API
        # @api public
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
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Array<Space>] the spaces that were found
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up many spaces
          #   client.find_spaces(["1DXxyRYNejbKM", "1OwGWzarWnNKQ"]).map(&:title)
          def find_spaces(ids, **params, &)
            Space.find_all(ids, client: self, **params, &)
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
end
