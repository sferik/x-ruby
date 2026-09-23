# frozen_string_literal: true

module X
  module Objects
    # The number the API publishes for a collection of a resource, such as the followers_count of a user, which a
    # cursor over the collection reads, included into Resource
    # @api private
    module PublishedCount
      private

      # A block reading the attribute holding the number the API publishes
      #
      # A resource without the attribute, such as a stub, is hydrated to read it, which costs one lookup rather than
      # paging through the collection. Given fresh: true, as by a cursor that was refreshed, the block looks the
      # resource up again, as refresh does, to read the number the API publishes now.
      #
      # @api private
      # @param total [Symbol, nil] the attribute name, or nil if the API publishes no number
      # @return [Proc, nil] the block, or nil if the API publishes no number
      def counter(total)
        return if total.nil?

        lambda do |fresh: false|
          # @type var fresh: bool
          fresh ? refresh&.public_send(total) : public_send(total) || hydrate&.public_send(total)
        end
      end
    end
  end
end
