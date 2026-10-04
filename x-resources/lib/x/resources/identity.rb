# frozen_string_literal: true

module X
  module Resources
    # Equality and hashing by class and identifier, so the same resource fetched twice compares equal
    #
    # Internal to x-resources: the methods it gives a resource, such as ==, are public API, but the module is only how
    # they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api semipublic
    module Identity
      # Compare resources by class and identifier
      #
      # @api public
      # @param other [Object] the object to compare with
      # @return [Boolean] true if the other object is the same kind of resource with the same identifier
      # @example Compare users fetched in different requests
      #   post.author == client.find_user("sferik")
      def ==(other)
        self.class.equal?(other.class) && id.eql?(other.id)
      end

      # @!method eql?(other)
      #   Alias for ==, compares resources by class and identifier
      #   @api public
      #   @param other [Object] the object to compare with
      #   @return [Boolean] true if the other object is the same kind of resource with the same identifier
      #   @example Deduplicate resources
      #     [user, client.find_user("sferik")].uniq
      alias_method :eql?, :==

      # Hash resources by class and identifier
      #
      # @api public
      # @return [Integer] the hash code
      # @example Use resources as hash keys
      #   {user => 1}[client.find_user("sferik")]
      def hash
        [self.class, id].hash
      end

      # Deconstruct the resource into its attributes, so it matches a hash pattern
      #
      # Every attribute the resource declares is read as its own method reads it, so a pattern sees the
      # identifier as a number, a timestamp as a Time, and a metric by the name it is read by. A pattern can ask
      # for an attribute by another name it is read by, such as retweet_count for repost_count, and a pattern
      # that asks for every attribute, with a double splat, gets each once, by the name the resource declares.
      #
      # @api public
      # @param keys [Array<Symbol>, nil] the keys the pattern asks for, or nil for every attribute
      # @return [Hash{Symbol => Object}] the attributes
      # @example Match a post by its author
      #   puts "by sferik" if post in {author_id: 7505382}
      # @example Match a post by a name from before posts were posts
      #   puts "widely reposted" if post in {retweet_count: 100..}
      def deconstruct_keys(keys)
        klass = self.class
        names = klass.__send__(:attribute_names)
        names = (names + klass.__send__(:attribute_aliases)) & keys unless keys.nil?
        names.to_h { |name| [name, public_send(name)] }
      end
    end
    private_constant :Identity
  end
end
