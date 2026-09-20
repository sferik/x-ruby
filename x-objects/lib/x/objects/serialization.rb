require "json"

module X
  module Objects
    # Serialization of what an API response held, by its attributes alone
    #
    # ActiveSupport's Object#as_json would otherwise read the instance variables, which hold the client and so its
    # credentials, and loop for good once a reference has resolved.
    #
    # @api public
    module Serialization
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
  end
end
