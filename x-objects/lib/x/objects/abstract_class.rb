# frozen_string_literal: true

module X
  module Objects
    # Makes new and from_id, which Resource keeps private, public on each class of resource
    #
    # Resource is the class each resource descends from, and is not a resource itself: one built of it has no endpoint
    # to hydrate from, and raises UnsupportedOperation for it, so it builds none.
    #
    # @api private
    module AbstractClass
      private

      # Make new and from_id public on each class that descends from this one
      #
      # @api private
      # @param subclass [Class] the class that descends from it
      # @return [void]
      def inherited(subclass)
        super
        subclass.public_class_method(:new, :from_id)
      end
    end
    private_constant :AbstractClass
  end
end
