# frozen_string_literal: true

require_relative "errors"
require_relative "batch_finders"
require_relative "utils"

module X
  module Objects
    # Class methods that look users up by identifier or username, and the authenticated user, extended into User
    #
    # Internal to x-objects: the methods it gives User, such as X::User.find_by_username, are public API, but the module
    # is only how they are shared, and which classes extend or include it can change within 1.x.
    #
    # @api private
    module UserFinders
      include BatchFinders

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

        find_by_username(_ = id_or_username, client:, **params, &)
      end

      # Look up a user by identifier or username, which must exist
      #
      # An Integer or a user is looked up by identifier, and a String by username, as find looks them up, so the error
      # it raises names a username as find_by_username! names one, with the at sign of a handle.
      #
      # @api public
      # @param id_or_username [Integer, User, String] an identifier or a user, or a username
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User] the user
      # @raise [ArgumentError] if the value is neither an identifier nor a username
      # @raise [MissingResource] if the user was not found
      # @example Look up a user by username
      #   X::User.find!("sferik", client: client)
      def find!(id_or_username, client:, **params)
        return super if Utils.id?(id_or_username)

        find_by_username!(_ = id_or_username, client:, **params)
      end

      # Look up many users by identifier or username, in parallel batches
      #
      # Integers and users are looked up by identifier, and Strings by username. The users come back in the
      # order they were asked for, one for each value that was found, so a user asked for twice, by identifier or by
      # username, comes back twice, without the ones that were not found. Every username is checked before any
      # request, so one that is not a username raises before the identifiers are looked up, and billed.
      #
      # @api public
      # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; the
      #   identifiers and the usernames are looked up one kind after the other, each kind that many batches at a time
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found, one for each value that names one, frozen
      # @raise [ArgumentError] if a String is not a username, or if the concurrency is less than one, before any request
      # @yieldparam problem [Problem] each problem the API reported, such as a user that was not found
      # @example Look up many users by username
      #   X::User.find_all(["sferik", "gem"], client: client)
      def find_all(ids_or_usernames, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        ids, usernames = ids_or_usernames.partition { |value| Utils.id?(value) }
        usernames.each { |username| Utils.username!(username) }
        found = super(ids, client:, concurrency:, **params) #: Array[User]
        in_order(found + find_all_by_username(_ = usernames, client:, concurrency:, **params, &), ids_or_usernames)
      end

      # Look up many users by identifier, in parallel batches
      #
      # A String of digits is an identifier, as it is read from a response or an environment variable, so this looks
      # the accounts those numbers identify up, where find_all would take them for usernames. The users come back in
      # the order they were asked for, one for each identifier that was found, as find_all returns them.
      #
      # @api public
      # @param ids [Array<String, Integer, User>] the identifiers, or users
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found, one for each identifier that names one, frozen
      # @raise [ArgumentError] if a value is not an identifier, or if the concurrency is less than one
      # @yieldparam problem [Problem] each problem the API reported, such as an identifier that was not found
      # @example Look up many users by identifier, read as Strings
      #   X::User.find_all_by_id(ENV.fetch("USER_IDS").split(","), client: client)
      def find_all_by_id(ids, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        ids = ids.map { |id| Utils.id_of(id, self) }
        in_order_of(lookup_in_batches(endpoint!, batch_key, ids, client:, concurrency:, **params, &), ids) #: Array[User]
      end

      # Look up a user by identifier
      #
      # A String of digits is an identifier, as it is read from a response or an environment variable, so this looks
      # the account that number identifies up, where find would take it for a username.
      #
      # @api public
      # @param id [String, Integer, User] the identifier, or a user
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User, nil] the user or nil if the user was not found
      # @raise [ArgumentError] if the value is not an identifier
      # @yieldparam problem [Problem] each problem the API reported, such as a user that was not found
      # @example Look up a user by an identifier read as a String
      #   X::User.find_by_id(ENV.fetch("USER_ID"), client: client)
      def find_by_id(id, client:, **params, &)
        lookup("#{endpoint!}/#{Utils.id_of(id, self)}", client:, **params, &) #: User?
      end

      # Look up a user by identifier, which must exist
      #
      # @api public
      # @param id [String, Integer, User] the identifier, or a user
      # @param client [Object] the client used to make the request
      # @param params [Hash] query parameters merged over the default parameters
      # @return [User] the user
      # @raise [ArgumentError] if the value is not an identifier
      # @raise [MissingResource] if the user was not found
      # @example Look up a user by an identifier read as a String
      #   X::User.find_by_id!("7505382", client: client)
      def find_by_id!(id, client:, **params)
        problems = [] #: Array[Problem]
        find_by_id(id, client:, **params) { |problem| problems << problem } || raise(MissingResource.new("Could not find #{self} #{Utils.id_of(id, self)}", problems:))
      end

      # Look up many users by username, in parallel batches
      #
      # The users come back in the order they were asked for, one for each username that was found, whatever its
      # case, as find_all returns them, and each username is asked for once, however often, and in whatever case, it
      # is given.
      #
      # @api public
      # @param usernames [Array<String>] the usernames, with or without leading at signs
      # @param client [Object] the client used to make the requests
      # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
      # @param params [Hash] query parameters merged over the default parameters
      # @return [Array<User>] the users that were found, one for each username that names one, frozen
      # @raise [ArgumentError] if a value is not a username, or if the concurrency is less than one
      # @yieldparam problem [Problem] each problem the API reported, such as a username that was not found
      # @example Look up many users by username
      #   X::User.find_all_by_username(["sferik", "gem"], client: client)
      def find_all_by_username(usernames, client:, concurrency: DEFAULT_CONCURRENCY, **params, &)
        usernames = usernames.map { |username| normalize(Utils.username!(username)) }
        found = lookup_in_batches("users/by", :usernames, usernames, client:, concurrency:, **params, &) #: Array[User]
        in_order(found, usernames)
      end

      # Look up a user by username
      #
      # It looks every value up as a username, a String of digits as the account whose handle is that number, as find
      # looks up any String, so code that reads a value from elsewhere says which it means, as find_by_id does.
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

      # Order users as they were asked for, one for each value that names one
      # @api private
      # @param users [Array<User>] the users found
      # @param ids_or_usernames [Array<Integer, User, String>] the identifiers, users, and usernames asked for
      # @return [Array<User>] the user each value names, in the order of the values, frozen
      def in_order(users, ids_or_usernames)
        by_key = users.to_h { |user| [key_of(user), user] }.merge(users.to_h { |user| [key_of(user.username), user] })
        ids_or_usernames.filter_map { |value| by_key[key_of(value)] }.freeze
      end

      # The key that matches a user to the identifier or username it was asked for by
      # @api private
      # @param value [Integer, User, String] an identifier or user, or a username
      # @return [String] the identifier, or the username in lowercase after an at sign
      def key_of(value)
        Utils.id?(value) ? Utils.id_of(value, self) : "@#{normalize(value)}"
      end

      # A username without an at sign, in lowercase, since case does not matter
      # @api private
      # @param username [String] the username, with or without a leading at sign
      # @return [String] the normalized username
      def normalize(username) = Utils.username(username).downcase
    end
    private_constant :UserFinders
  end
end
