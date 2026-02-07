module X
  # Methods for the Users Lookup API
  # @see https://docs.x.com/x-api/users/lookup/introduction
  # @api public
  module Users
    # Retrieve a single user by ID
    #
    # @param id [String, Integer] the user ID
    # @param user_fields [Array<String>, String, nil] list of user fields to return
    # @param expansions [Array<String>, String, nil] list of expansions to include
    # @param tweet_fields [Array<String>, String, nil] list of tweet fields to return (requires pinned_tweet_id expansion)
    # @return [Hash] the parsed response body
    # @see https://docs.x.com/x-api/users/lookup/api-reference/get-users-id
    # @example Retrieve a user with default fields
    #   client.user("123456")
    # @example Retrieve a user with additional fields
    #   client.user("123456", user_fields: ["created_at", "description", "public_metrics"])
    def user(id, user_fields: nil, expansions: nil, tweet_fields: nil)
      get(build_users_endpoint("users/#{id}", user_fields:, expansions:, tweet_fields:))
    end

    # Retrieve multiple users by their IDs
    #
    # @param ids [Array<String>, Array<Integer>] list of user IDs (up to 100)
    # @param user_fields [Array<String>, String, nil] list of user fields to return
    # @param expansions [Array<String>, String, nil] list of expansions to include
    # @param tweet_fields [Array<String>, String, nil] list of tweet fields to return (requires pinned_tweet_id expansion)
    # @return [Hash] the parsed response body
    # @see https://docs.x.com/x-api/users/lookup/api-reference/get-users
    # @example Retrieve multiple users
    #   client.users(ids: ["123456", "789012"])
    # @example Retrieve multiple users with fields
    #   client.users(ids: ["123456", "789012"], user_fields: ["created_at", "public_metrics"])
    def users(ids:, user_fields: nil, expansions: nil, tweet_fields: nil)
      params = assemble_users_params(user_fields:, expansions:, tweet_fields:)
      params["ids"] = Array(ids).join(",")
      get("users?#{URI.encode_www_form(params)}")
    end

    # Retrieve a single user by username
    #
    # @param username [String] the username (without @ prefix)
    # @param user_fields [Array<String>, String, nil] list of user fields to return
    # @param expansions [Array<String>, String, nil] list of expansions to include
    # @param tweet_fields [Array<String>, String, nil] list of tweet fields to return (requires pinned_tweet_id expansion)
    # @return [Hash] the parsed response body
    # @see https://docs.x.com/x-api/users/lookup/api-reference/get-users-by-username-username
    # @example Retrieve a user by username
    #   client.user_by_username("sferik")
    # @example Retrieve a user by username with fields
    #   client.user_by_username("sferik", user_fields: ["created_at", "description"])
    def user_by_username(username, user_fields: nil, expansions: nil, tweet_fields: nil)
      get(build_users_endpoint("users/by/username/#{username}", user_fields:, expansions:, tweet_fields:))
    end

    # Retrieve multiple users by their usernames
    #
    # @param usernames [Array<String>] list of usernames (up to 100, without @ prefix)
    # @param user_fields [Array<String>, String, nil] list of user fields to return
    # @param expansions [Array<String>, String, nil] list of expansions to include
    # @param tweet_fields [Array<String>, String, nil] list of tweet fields to return (requires pinned_tweet_id expansion)
    # @return [Hash] the parsed response body
    # @see https://docs.x.com/x-api/users/lookup/api-reference/get-users-by
    # @example Retrieve users by usernames
    #   client.users_by_usernames(usernames: ["sferik", "xdevelopers"])
    # @example Retrieve users by usernames with fields
    #   client.users_by_usernames(usernames: ["sferik", "xdevelopers"], user_fields: ["created_at"])
    def users_by_usernames(usernames:, user_fields: nil, expansions: nil, tweet_fields: nil)
      params = assemble_users_params(user_fields:, expansions:, tweet_fields:)
      params["usernames"] = Array(usernames).join(",")
      get("users/by?#{URI.encode_www_form(params)}")
    end

    # Retrieve the authenticated user
    #
    # @param user_fields [Array<String>, String, nil] list of user fields to return
    # @param expansions [Array<String>, String, nil] list of expansions to include
    # @param tweet_fields [Array<String>, String, nil] list of tweet fields to return (requires pinned_tweet_id expansion)
    # @return [Hash] the parsed response body
    # @see https://docs.x.com/x-api/users/lookup/api-reference/get-users-me
    # @example Retrieve the authenticated user
    #   client.me
    # @example Retrieve the authenticated user with fields
    #   client.me(user_fields: ["created_at", "description", "public_metrics"])
    def me(user_fields: nil, expansions: nil, tweet_fields: nil)
      get(build_users_endpoint("users/me", user_fields:, expansions:, tweet_fields:))
    end

    private

    # Build an endpoint path with optional query parameters
    # @api private
    def build_users_endpoint(path, user_fields: nil, expansions: nil, tweet_fields: nil)
      params = assemble_users_params(user_fields:, expansions:, tweet_fields:)
      return path if params.empty?

      "#{path}?#{URI.encode_www_form(params)}"
    end

    # Assemble query parameters hash from field options
    # @api private
    def assemble_users_params(user_fields: nil, expansions: nil, tweet_fields: nil)
      params = {}
      params["user.fields"] = Array(user_fields).join(",") if user_fields
      params["expansions"] = Array(expansions).join(",") if expansions
      params["tweet.fields"] = Array(tweet_fields).join(",") if tweet_fields
      params
    end
  end
end
