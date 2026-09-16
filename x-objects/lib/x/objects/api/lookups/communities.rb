require_relative "../../community"

module X
  module Objects
    module API
      module Lookups
        # Look up and search communities, mixed into a client through API
        # @api public
        module Communities
          # Look up a community by identifier
          #
          # @api public
          # @param id [String, Integer, Community] the identifier
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Community, nil] the community or nil if the community was not found
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up a community
          #   client.find_community(1234567890).name
          def find_community(id, **params, &)
            Community.find(id, client: self, **params, &)
          end

          # Look up a community by identifier, which must exist
          #
          # @api public
          # @param id [String, Integer, Community] the identifier
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Community] the community
          # @raise [ResourceNotFound] if the community was not found
          # @example Look up a community
          #   client.find_community!(1234567890).name
          def find_community!(id, **params)
            Community.find!(id, client: self, **params)
          end

          # Search communities
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Cursor] a cursor over the matching communities
          # @example Print the communities matching a query
          #   client.search_communities("ruby").each { |community| puts community.name }
          def search_communities(query, **params)
            Community.search(query, client: self, **params)
          end
        end
      end
    end
  end
end
