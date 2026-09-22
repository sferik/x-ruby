# frozen_string_literal: true

require_relative "../../user"

module X
  module Objects
    module API
      module Lookups
        # Look up and search users, and the authenticated user, mixed into a client through API
        # @api public
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
          # A String of digits is a username, so this looks the account whose handle is that number up, where
          # find_user would take it for an identifier.
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
          def find_all_users(ids_or_usernames, concurrency: Finders::DEFAULT_CONCURRENCY, **params, &)
            User.find_all(ids_or_usernames, client: self, concurrency:, **params, &)
          end

          # Look up many users by username, in parallel batches
          #
          # A String of digits is a username, so this looks the accounts whose handles are those numbers up, where
          # find_all_users would take them for identifiers.
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
          def find_all_users_by_username(usernames, concurrency: Finders::DEFAULT_CONCURRENCY, **params, &)
            User.find_all_by_username(usernames, client: self, concurrency:, **params, &)
          end

          # The authenticated user, fetched once per client and credentials
          #
          # A client whose credentials change authenticates as someone else, so a client that has an authenticator
          # fetches the user again once the authenticator is replaced.
          #
          # @api public
          # @return [User] the authenticated user
          # @raise [MissingResource] if the API returns no user
          # @example Print the home timeline of the authenticated user
          #   client.current_user!.home_timeline.each { |post| puts post.text }
          def current_user!
            authenticator = Utils.authenticator_of(self)
            owner, user = @current_user
            return user if user && owner.equal?(authenticator)

            user = User.current!(client: self)
            @current_user = [authenticator, user]
            user
          end

          # The identifier of the authenticated user, from an OAuth 1.0a token if possible
          #
          # An OAuth 1.0a access token begins with the identifier of its user, so a client that holds one needs no
          # lookup. Any other client looks the user up once, as current_user! does.
          #
          # @api public
          # @return [Integer] the identifier
          # @example Get the identifier of the authenticated user
          #   client.current_user_id # => 7505382
          def current_user_id = Utils.authenticated_user_id(self) || current_user!.id

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
