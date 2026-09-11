module X
  module Objects
    # Equality and hashing by class and identifier, so the same resource fetched twice compares equal
    # @api public
    module Identity
      # Compare resources by class and identifier
      #
      # @api public
      # @param other [Object] the object to compare with
      # @return [Boolean] true if the other object is the same kind of resource with the same identifier
      # @example Compare users fetched in different requests
      #   post.author == client.user("sferik")
      def ==(other)
        self.class.equal?(other.class) && id.eql?(other.id)
      end

      # @!method eql?(other)
      #   Alias for ==, compares resources by class and identifier
      #   @api public
      #   @param other [Object] the object to compare with
      #   @return [Boolean] true if the other object is the same kind of resource with the same identifier
      #   @example Deduplicate resources
      #     [user, client.user("sferik")].uniq
      alias_method :eql?, :==

      # Hash resources by class and identifier
      #
      # @api public
      # @return [Integer] the hash code
      # @example Use resources as hash keys
      #   {user => 1}[client.user("sferik")]
      def hash
        [self.class, id].hash
      end
    end
  end
end
