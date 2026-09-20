# frozen_string_literal: true

require_relative "memo"

module X
  module Objects
    # A group of stubs, no more than one lookup takes, that hydrate together in one request rather than one each
    # @api private
    class Batch
      # Initialize a batch over some identifiers
      #
      # @api private
      # @param klass [Class] the class of the resources
      # @param ids [Array<String, Integer>] the identifiers
      # @param client [Object] the client used to make the requests
      # @return [Batch] a new batch
      def initialize(klass, ids, client:)
        @klass = klass
        @ids = ids
        @client = client
        @memo = Memo.new
        freeze
      end

      # The resource of one identifier, looking up every identifier of the batch at once
      #
      # @api private
      # @param id [String, Integer] the identifier
      # @return [Resource, nil] the resource, or nil if it was not found
      def fetch(id) = resources[id]

      private

      # The resources of the batch, keyed by identifier
      # @api private
      # @return [Hash{Object => Resource}] the resources
      def resources
        @memo.fetch { @klass.find_all(@ids, client: @client).to_h { |resource| [resource.id, resource] } }
      end
    end
  end
end
