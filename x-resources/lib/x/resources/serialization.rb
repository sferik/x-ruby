# frozen_string_literal: true

require "json"

module X
  module Resources
    # Serialization of what an API response held, by its attributes alone
    #
    # ActiveSupport's Object#as_json would otherwise read the instance variables, which hold the client and so its
    # credentials, and loop for good once a reference has resolved.
    #
    # Internal to x-resources: the methods it gives a resource, X::PostUsage, and the other values of the object layer, such
    # as to_json, are public API, but the module is only how they are shared, and which classes extend or include it
    # can change within 1.x.
    #
    # @api semipublic
    module Serialization
      # The attributes, or with a block the Hash of the pairs it returns for them
      #
      # With a block it is the to_h of the attributes, as a Hash builds it, rather than the attributes, the block ignored.
      #
      # @api public
      # @yieldparam key [String] the name of each attribute
      # @yieldparam value [Object] its value
      # @yieldreturn [Array(Object, Object)] the key and value of the attribute in the Hash
      # @return [Hash] the attributes, frozen, or the pairs the block returns
      # @example Convert a resource to a hash
      #   user.to_h # => {"id" => "7505382", "username" => "sferik"}
      # @example Key the attributes by Symbol
      #   user.to_h { |key, value| [key.to_sym, value] } # => {id: "7505382", username: "sferik"}
      # @example Delete the rule a post matched
      #   streaming_client.delete_rules(post.matching_rules.first.to_h)
      def to_h(&) = attrs.to_h(&) # steep:ignore BlockTypeMismatch

      # The attributes, as a JSON encoder and ActiveSupport read them
      #
      # @api public
      # @return [Hash{String => Object}] the attributes
      # @example Serialize a resource
      #   user.as_json # => {"id" => "7505382", "username" => "sferik"}
      # @example Serialize a problem
      #   problem.as_json # => {"title" => "Not Found Error"}
      def as_json(*) = attrs

      # The attributes as JSON
      #
      # @api public
      # @param state [JSON::State, nil] the state a JSON encoder passes, which the attributes are given
      # @return [String] the attributes as a JSON object
      # @example Serialize a resource
      #   user.to_json # => "{\"id\":\"7505382\",\"username\":\"sferik\"}"
      # @example Cache a resource as JSON
      #   Rails.cache.write("user", user.to_json)
      def to_json(state = nil) = as_json.to_json(state)
    end
    private_constant :Serialization
  end
end
