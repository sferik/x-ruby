# frozen_string_literal: true

require_relative "../../user"

module X
  module Objects
    module API
      module Lookups
        # Look up and search users, and the authenticated user, mixed into a client through API
        #
        # Internal to x-objects: X::Objects::API includes it, and its methods are public API of the client that
        # includes API, but the module is only how they are grouped, and some of them need the methods of another,
        # so include API rather than this module alone.
        #
        # @api private
        module Users
          # Look up a user by identifier or username
          #
          # @api public
          # @param id_or_username [Integer, User, String] an identifier or a user, or a username
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User, nil] the user or nil if the user was not found
          # @example Look up a user by username
          #   client.find_user("sferik")
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up a user by identifier
          #   client.find_user(7505382)
          def find_user(id_or_username, **params, &)
            User.find(id_or_username, client: self, **params, &)
          end

          # Look up a user by identifier or username, which must exist
          #
          # @api public
          # @param id_or_username [Integer, User, String] an identifier or a user, or a username
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User] the user
          # @raise [MissingResource] if the user was not found
          # @example Look up a user by username
          #   client.find_user!("sferik")
          def find_user!(id_or_username, **params)
            User.find!(id_or_username, client: self, **params)
          end

          # Look up a user by username
          #
          # It looks every value up as a username, a String of digits as the account whose handle is that number, as
          # find_user looks up any String, so code that reads a value from elsewhere says which it means, as
          # find_user_by_id does.
          #
          # @api public
          # @param username [String] the username, with or without a leading at sign
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User, nil] the user or nil if the user was not found
          # @raise [ArgumentError] if the value is not a username
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up a user whose username is a number
          #   client.find_user_by_username("1234567890")
          def find_user_by_username(username, **params, &)
            User.find_by_username(username, client: self, **params, &)
          end

          # Look up a user by username, which must exist
          #
          # @api public
          # @param username [String] the username, with or without a leading at sign
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User] the user
          # @raise [ArgumentError] if the value is not a username
          # @raise [MissingResource] if the user was not found
          # @example Look up a user by username
          #   client.find_user_by_username!("sferik")
          def find_user_by_username!(username, **params)
            User.find_by_username!(username, client: self, **params)
          end

          # Look up a user by identifier
          #
          # A String of digits is an identifier, as it is read from a response or an environment variable, so this
          # looks the account that number identifies up, where find_user would take it for a username.
          #
          # @api public
          # @param id [String, Integer, User] the identifier, or a user
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User, nil] the user or nil if the user was not found
          # @raise [ArgumentError] if the value is not an identifier
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up a user by an identifier read as a String
          #   client.find_user_by_id(ENV.fetch("USER_ID"))
          def find_user_by_id(id, **params, &)
            User.find_by_id(id, client: self, **params, &)
          end

          # Look up a user by identifier, which must exist
          #
          # @api public
          # @param id [String, Integer, User] the identifier, or a user
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User] the user
          # @raise [ArgumentError] if the value is not an identifier
          # @raise [MissingResource] if the user was not found
          # @example Look up a user by an identifier read as a String
          #   client.find_user_by_id!("7505382")
          def find_user_by_id!(id, **params)
            User.find_by_id!(id, client: self, **params)
          end

          # Look up many users by identifier or username, in parallel batches
          #
          # @api public
          # @param ids_or_usernames [Array<Integer, User, String>] identifiers or users, or usernames
          # @param concurrency [Integer] the number of batches looked up at once, which must be at least one; each is
          #   a request of up to 100 users, so a lower number spends a rate limit more slowly
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Array<User>] the users that were found
          # @raise [ArgumentError] if the concurrency is less than one
          # @yieldparam problem [Problem] each problem the API reported, such as a resource that was not found
          # @example Look up many users by username
          #   client.find_all_users(["sferik", "gem"])
          # @example Look up many users one batch at a time
          #   client.find_all_users(ids, concurrency: 1)
          def find_all_users(ids_or_usernames, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
            User.find_all(ids_or_usernames, client: self, concurrency:, **params, &)
          end

          # Look up many users by username, in parallel batches
          #
          # It looks every value up as a username, Strings of digits as the accounts whose handles are those numbers,
          # as find_all_users looks up any String, so code that reads values from elsewhere says which it means, as
          # find_all_users_by_id does.
          #
          # @api public
          # @param usernames [Array<String>] the usernames, with or without leading at signs
          # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Array<User>] the users that were found
          # @raise [ArgumentError] if a value is not a username, or if the concurrency is less than one
          # @yieldparam problem [Problem] each problem the API reported, such as a username that was not found
          # @example Look up many users by username
          #   client.find_all_users_by_username(["sferik", "1234567890"])
          def find_all_users_by_username(usernames, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
            User.find_all_by_username(usernames, client: self, concurrency:, **params, &)
          end

          # Look up many users by identifier, in parallel batches
          #
          # A String of digits is an identifier, as it is read from a response or an environment variable, so this
          # looks the accounts those numbers identify up, where find_all_users would take them for usernames.
          #
          # @api public
          # @param ids [Array<String, Integer, User>] the identifiers, or users
          # @param concurrency [Integer] the number of batches looked up at once, which must be at least one
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Array<User>] the users that were found
          # @raise [ArgumentError] if a value is not an identifier, or if the concurrency is less than one
          # @yieldparam problem [Problem] each problem the API reported, such as an identifier that was not found
          # @example Look up many users by identifier, read as Strings
          #   client.find_all_users_by_id(ENV.fetch("USER_IDS").split(","))
          def find_all_users_by_id(ids, concurrency: BatchFinders::DEFAULT_CONCURRENCY, **params, &)
            User.find_all_by_id(ids, client: self, concurrency:, **params, &)
          end

          # Look up the authenticated user
          #
          # Each call looks the user up, as X::User.current does, so its counts and profile are as they are now. Keep
          # the user it returns to read them again without a request.
          #
          # @api public
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User, nil] the authenticated user, or nil if the API returns none
          # @yieldparam problem [Problem] each problem the API reported
          # @example Print the name of the authenticated user
          #   puts client.current_user&.name
          def current_user(**params, &)
            User.current(client: self, **params, &)&.tap { |user| Utils.remember_user_id(self, user.id) }
          end

          # Look up the authenticated user, who must be found
          #
          # Each call looks the user up, as X::User.current! does, so its counts and profile are as they are now. Keep
          # the user it returns to read them again without a request.
          #
          # @api public
          # @param params [Hash] query parameters merged over the default parameters
          # @return [User] the authenticated user
          # @raise [MissingResource] if the API returns no user
          # @example Print the home timeline of the authenticated user
          #   client.current_user!.home_timeline.each { |post| puts post.text }
          def current_user!(**params)
            User.current!(client: self, **params).tap { |user| Utils.remember_user_id(self, user.id) }
          end

          # The identifier of the authenticated user, from an OAuth 1.0a token if possible
          #
          # An OAuth 1.0a access token begins with the identifier of its user, so a client that holds one needs no
          # lookup. Any other client looks the user up the first time, unless current_user or current_user! already
          # has, and keeps the identifier, which never changes, for as long as it holds the same authenticator, since
          # a client whose credentials change authenticates as someone else. A frozen client keeps nothing, and looks
          # the user up each time.
          #
          # @api public
          # @return [Integer] the identifier
          # @raise [MissingResource] if the user is looked up and the API returns none
          # @example Get the identifier of the authenticated user
          #   client.current_user_id # => 7505382
          def current_user_id = Utils.authenticated_user_id(self) || Utils.remembered_user_id(self) || current_user!.id

          # Search users
          #
          # @api public
          # @param query [String] the search query
          # @param params [Hash] query parameters merged over the default parameters
          # @return [Cursor] a cursor over the matching users
          # @example Print the users matching a query
          #   client.search_users("ruby").each { |user| puts user.username }
          def search_users(query, **params)
            User.search(query, client: self, **params)
          end
        end
      end
    end
  end
end
