require_relative "../../list"

module X
  module Objects
    module API
      module Actions
        # Create and delete lists as the authenticated user
        # @api public
        module Lists
          # Create a list owned by the authenticated user
          #
          # @api public
          # @param name [String] the name of the list
          # @param params [Hash] additional request body fields: description and private
          # @return [List, nil] the created list, holding only its identifier and name
          # @example Create a private list
          #   client.create_list("Rubyists", private: true)
          def create_list(name, **params)
            List.create(name, client: self, **params)
          end

          # Delete a list as the authenticated user
          #
          # @api public
          # @param list [List, String, Integer] the list or its identifier
          # @return [Boolean] true if the list was deleted
          # @example Delete a list
          #   client.delete_list("1234567890")
          def delete_list(list)
            List.delete(list, client: self)
          end
        end
      end
    end
  end
end
