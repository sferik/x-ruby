require_relative "errors"
require_relative "utils"

module X
  module Objects
    # Class methods that look users up by identifier or username, and the authenticated user, extended into User
    # @api public
    module UserFinders
      # Look up a user by identifier or username
      #
      # An Integer or a user is looked up by identifier, and a String by username, with or without a leading at sign.
      #
      # @api public
      # @param id_or_username [Integer, User, String] an identifier or a user, or a username
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the user or nil if the user was not found
      # @raise [ArgumentError] if the value is neither an identifier nor a username
      # @yieldparam problem [Problem] each problem the API reported, such as a user that was not found
      # @example Look up a user by username
      #   X::User.find("sferik", client: client)
      def find(id_or_username, client:, **params, &)
        return super if Utils.id?(id_or_username)

        find_by_username(id_or_username, client:, **params, &)
      end

      # Look up many users by identifier or username, in parallel batches
      #
      # Integers and users are looked up by identifier, and Strings by username. The users come back in the
      # order they were asked for, each once, without the ones that were not found.
      #
      # @api public
      # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found
      # @yieldparam problem [Problem] each problem the API reported, such as a user that was not found
      # @example Look up many users by username
      #   X::User.find_all(["sferik", "gem"], client: client)
      def find_all(ids_or_usernames, client:, **params, &)
        ids, usernames = ids_or_usernames.partition { |value| Utils.id?(value) }
        found = super(ids, client:, **params) #: Array[User]
        in_order(found + find_all_by_username(usernames, client:, **params, &), ids_or_usernames)
      end

      # Look up many users by username, in parallel batches, once each
      #
      # @api public
      # @param usernames [Array<String>] the usernames, with or without leading at signs
      # @param client [Object] the client used to make the requests
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found
      # @raise [ArgumentError] if a value is not a username
      # @yieldparam problem [Problem] each problem the API reported, such as a username that was not found
      # @example Look up many users by username
      #   X::User.find_all_by_username(["sferik", "gem"], client: client)
      def find_all_by_username(usernames, client:, **params, &)
        lookup_in_batches("users/by", :usernames, usernames.map { |username| normalize(Utils.username!(username)) }, client:, **params, &) #: Array[User]
      end

      # Look up a user by username
      #
      # A String of digits is a username, so this looks the account whose handle is that number up, where find would
      # take it for an identifier.
      #
      # @api public
      # @param username [String] the username, with or without a leading at sign
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the user or nil if the user was not found
      # @raise [ArgumentError] if the value is not a username
      # @yieldparam problem [Problem] each problem the API reported, such as a user that was not found
      # @example Look up a user by username
      #   X::User.find_by_username("sferik", client: client)
      def find_by_username(username, client:, **params, &)
        lookup("users/by/username/#{Utils.username!(username)}", client:, **params, &) #: User?
      end

      # Look up a user by username, which must exist
      #
      # @api public
      # @param username [String] the username, with or without a leading at sign
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User] the user
      # @raise [ArgumentError] if the value is not a username
      # @raise [MissingResource] if the user was not found
      # @example Look up a user by username
      #   X::User.find_by_username!("sferik", client: client)
      def find_by_username!(username, client:, **params)
        problems = [] #: Array[Problem]
        find_by_username(username, client:, **params) { |problem| problems << problem } || raise(MissingResource.new("Could not find #{self} @#{Utils.username(username)}", problems:))
      end

      # Look up the authenticated user
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the authenticated user
      # @yieldparam problem [Problem] each problem the API reported
      # @example Look up the authenticated user
      #   X::User.current(client: client)
      def current(client:, **params, &)
        lookup("users/me", client:, **params, &) #: User?
      end

      # Look up the authenticated user, who must be found
      #
      # @api public
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User] the authenticated user
      # @raise [MissingResource] if the API returns no user
      # @example Look up the authenticated user
      #   X::User.current!(client: client)
      def current!(client:, **params)
        problems = [] #: Array[Problem]
        current(client:, **params) { |problem| problems << problem } || raise(MissingResource.new("users/me returned no user", problems:))
      end

      private

      # Order users as they were asked for, each once
      # @api private
      # @param users [Array<User>] the users found
      # @param ids_or_usernames [Array<Integer, User, String>] the identifiers, users, and usernames asked for
      # @return [Array<User>] the users, in the order of the first value that matches each
      def in_order(users, ids_or_usernames)
        by_key = users.to_h { |user| [key_of(user), user] }.merge(users.to_h { |user| [key_of(user.username), user] })
        ids_or_usernames.filter_map { |value| by_key[key_of(value)] }.uniq
      end

      # The key that matches a user to the identifier or username it was asked for by
      # @api private
      # @param value [Integer, User, String] an identifier or user, or a username
      # @return [String] the identifier, or the username in lowercase after an at sign
      def key_of(value)
        Utils.id?(value) ? Utils.id_of(value) : "@#{normalize(value)}"
      end

      # A username without an at sign, in lowercase, since case does not matter
      # @api private
      # @param username [String] the username, with or without a leading at sign
      # @return [String] the normalized username
      def normalize(username) = Utils.username(username).downcase
    end
  end
end
