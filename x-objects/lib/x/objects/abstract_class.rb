# frozen_string_literal: true

module X
  module Objects
    # Makes new, from_id, and from_response, which Resource keeps private, public on each class of resource
    #
    # Resource is the class each resource descends from, and is not a resource itself: one built of it has no endpoint
    # to hydrate from, and raises UnsupportedOperation for it, so it builds none.
    #
    # @api private
    module AbstractClass
      # The class methods that build a resource, which a class of resource makes public
      BUILDERS = %i[new from_id from_response].freeze

      private

      # Make the builders public on each class that descends from this one
      #
      # @api private
      # @param subclass [Class] the class that descends from it
      # @return [void]
      def inherited(subclass)
        super
        subclass.public_class_method(BUILDERS)
      end
    end
    private_constant :AbstractClass
  end
end
