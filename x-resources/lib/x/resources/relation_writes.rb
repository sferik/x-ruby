# frozen_string_literal: true

require_relative "user"
require_relative "utils"

module X
  module Resources
    # Relating users, posts, and lists to the authenticated user, and removing the relations
    #
    # A relation, such as following a user or liking a post, is written as the authenticated user alone, so the methods
    # of a client that write one, such as follow and like, write it here, for the user the client authenticates as,
    # and no user does.
    #
    # @api private
    module RelationWrites
      extend self

      # Relate a resource to the authenticated user and report the resulting state
      #
      # @api private
      # @param client [Object] the client used to make the request
      # @param user [Integer, String] the identifier of the authenticated user
      # @param relation [String] the relation endpoint, such as following, likes, or pinned_lists
      # @param field [Hash{String => String}] the request body, the identifier of the related resource under its field
      # @param states [Array<String>] the response fields reporting the state, any of which is true once it exists
      # @return [Boolean] true if the relation now exists
      # @raise [ArgumentError] if the identifier of the authenticated user is not a number, before a request
      # @example Like a post as the authenticated user
      #   X::Resources::RelationWrites.relate(client, client.current_user_id, "likes", {"tweet_id" => "1234567890"}, "liked")
      def relate(client, user, relation, field, *states)
        body = client.post("users/#{Utils.id_of(user, User)}/#{relation}", field, **Utils::JSON_CLASSES)
        states.any? { |state| Utils.written(body, state).eql?(true) }
      end

      # Remove a relation from the authenticated user and report the resulting state
      #
      # @api private
      # @param client [Object] the client used to make the request
      # @param user [Integer, String] the identifier of the authenticated user
      # @param relation [String] the relation endpoint, such as following, likes, or pinned_lists
      # @param target [String] the identifier of the related resource
      # @param state [String] the response field reporting the state
      # @return [Boolean] true if the relation no longer exists
      # @raise [ArgumentError] if the identifier of the authenticated user is not a number, before a request
      # @example Unlike a post as the authenticated user
      #   X::Resources::RelationWrites.unrelate(client, client.current_user_id, "likes", "1234567890", "liked")
      def unrelate(client, user, relation, target, state)
        body = client.delete("users/#{Utils.id_of(user, User)}/#{relation}/#{target}", **Utils::JSON_CLASSES)
        Utils.written(body, state).eql?(false)
      end
    end
    private_constant :RelationWrites
  end
end
