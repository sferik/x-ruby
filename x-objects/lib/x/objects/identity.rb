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

      # Deconstruct the resource into its identifier, so it matches an array pattern
      #
      # @api public
      # @return [Array] the identifier alone
      # @example Match a user by identifier
      #   case user in [7505382] then puts "sferik"
      #   end
      def deconstruct = [id]

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
      #   case post in {author_id: 7505382} then puts "by sferik"
      #   end
      # @example Match a post by a name from before posts were posts
      #   case post in {retweet_count: 100..} then puts "widely reposted"
      #   end
      def deconstruct_keys(keys)
        klass = self.class
        names = klass.attribute_names
        names = (names + klass.attribute_aliases) & keys unless keys.nil?
        names.to_h { |name| [name, public_send(name)] }
      end
    end
  end
end
