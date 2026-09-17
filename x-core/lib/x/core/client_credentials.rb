module X
  # Mixin for client authentication credentials
  # @api private
  module ClientCredentials
    # The API key for OAuth 1.0a authentication
    # @api public
    # @return [String, nil] the API key for OAuth 1.0a authentication
    # @example Get the API key
    #   client.api_key
    attr_reader :api_key

    # The API key secret for OAuth 1.0a authentication
    # @api public
    # @return [String, nil] the API key secret for OAuth 1.0a authentication
    # @example Get the API key secret
    #   client.api_key_secret
    attr_reader :api_key_secret

    # The access token secret for OAuth 1.0a authentication
    # @api public
    # @return [String, nil] the access token secret for OAuth 1.0a authentication
    # @example Get the access token secret
    #   client.access_token_secret
    attr_reader :access_token_secret

    # The bearer token for authentication
    # @api public
    # @return [String, nil] the bearer token for authentication
    # @example Get the bearer token
    #   client.bearer_token
    attr_reader :bearer_token

    # The OAuth 2.0 client ID
    # @api public
    # @return [String, nil] the OAuth 2.0 client ID
    # @example Get the client ID
    #   client.client_id
    attr_reader :client_id

    # The OAuth 2.0 client secret
    # @api public
    # @return [String, nil] the OAuth 2.0 client secret
    # @example Get the client secret
    #   client.client_secret
    attr_reader :client_secret

    # The access token for OAuth authentication, as last refreshed
    #
    # @api public
    # @return [String, nil] the access token for OAuth authentication
    # @example Get the access token
    #   client.access_token
    def access_token = oauth2_authenticator_in_use&.access_token || @access_token

    # The OAuth 2.0 refresh token, as last refreshed
    #
    # @api public
    # @return [String, nil] the OAuth 2.0 refresh token
    # @example Get the refresh token
    #   client.refresh_token
    def refresh_token = oauth2_authenticator_in_use&.refresh_token || @refresh_token

    # The time the OAuth 2.0 access token expires, as last refreshed
    #
    # @api public
    # @return [Time, nil] the expiration time, or nil if it is not known
    # @example Get the expiration time
    #   client.expires_at
    def expires_at = oauth2_authenticator_in_use&.expires_at || @expires_at

    # Set the API key for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key [String] the API key for OAuth 1.0a authentication
    # @return [void]
    # @example Set the API key
    #   client.api_key = "new_key"
    def api_key=(api_key)
      replace_credentials(api_key:)
    end

    # Set the API key secret for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key_secret [String] the API key secret for OAuth 1.0a authentication
    # @return [void]
    # @example Set the API key secret
    #   client.api_key_secret = "new_secret"
    def api_key_secret=(api_key_secret)
      replace_credentials(api_key_secret:)
    end

    # Set the access token for OAuth authentication
    #
    # @api public
    # @param access_token [String] the access token for OAuth authentication
    # @return [void]
    # @example Set the access token
    #   client.access_token = "new_token"
    def access_token=(access_token)
      replace_credentials(access_token:)
    end

    # Set the access token secret for OAuth 1.0a authentication
    #
    # @api public
    # @param access_token_secret [String] the access token secret for OAuth 1.0a authentication
    # @return [void]
    # @example Set the access token secret
    #   client.access_token_secret = "new_secret"
    def access_token_secret=(access_token_secret)
      replace_credentials(access_token_secret:)
    end

    # Set the bearer token for authentication
    #
    # Like every setter, this builds the client's authenticator from the first complete set of credentials the client
    # holds, so a client whose credentials no longer form any set sends requests without credentials. Change several
    # credentials at once with {#update_credentials}.
    #
    # @api public
    # @param bearer_token [String] the bearer token for authentication
    # @return [void]
    # @example Set the bearer token
    #   client.bearer_token = "new_token"
    def bearer_token=(bearer_token)
      replace_credentials(bearer_token:)
    end

    # Set the OAuth 2.0 client ID
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID
    # @return [void]
    # @example Set the client ID
    #   client.client_id = "new_id"
    def client_id=(client_id)
      replace_credentials(client_id:)
    end

    # Set the OAuth 2.0 client secret
    #
    # @api public
    # @param client_secret [String] the OAuth 2.0 client secret
    # @return [void]
    # @example Set the client secret
    #   client.client_secret = "new_secret"
    def client_secret=(client_secret)
      replace_credentials(client_secret:)
    end

    # Set the OAuth 2.0 refresh token
    #
    # @api public
    # @param refresh_token [String] the OAuth 2.0 refresh token
    # @return [void]
    # @example Set the refresh token
    #   client.refresh_token = "new_token"
    def refresh_token=(refresh_token)
      replace_credentials(refresh_token:)
    end

    # Set the time the OAuth 2.0 access token expires
    #
    # The first request after that time, less a buffer for clock skew, refreshes the token.
    #
    # @api public
    # @param expires_at [Time, nil] the expiration time, or nil if it is not known
    # @return [void]
    # @raise [ArgumentError] if the expiration time is neither a Time nor nil
    # @example Set the expiration time
    #   client.expires_at = Time.now + 7200
    def expires_at=(expires_at)
      replace_credentials(expires_at:)
    end

    # Change several credentials at once
    #
    # The client builds its authenticator once every change is made, so a request on another thread never signs with
    # a mix of old and new credentials, as it could between two setters when rotating an OAuth 1.0a access token and
    # its secret. Credentials left out keep their values, and a credential passed as nil is cleared.
    #
    # @api public
    # @param changes [Hash{Symbol => String, Time, nil}] the credentials to change, as initialize accepts them
    # @return [void]
    # @raise [ArgumentError] if the credentials, once changed, do not form a complete set, as initialize would raise,
    #   which leaves the client as it was
    # @example Rotate an OAuth 1.0a access token
    #   client.update_credentials(access_token: "new_token", access_token_secret: "new_secret")
    # @example Stop sending credentials
    #   client.update_credentials(bearer_token: nil)
    def update_credentials(**changes)
      self.class.new(**credentials, **changes)
      replace_credentials(**changes)
    end

    # A client that authenticates as the app, for the endpoints that refuse OAuth 1.0a
    #
    # A client that signs with OAuth 1.0a fetches an app-only bearer token with its API key and secret the first
    # time, and returns the same copy, with the connections it keeps open, until its credentials or settings change.
    # Any other client is returned as it is: one with a bearer token or an API
    # key and secret already authenticates as the app, and one that authenticates with OAuth 2.0 as a user holds no
    # credentials of the app to authenticate with, so the endpoints that take app-only authentication refuse it.
    #
    # @api public
    # @return [Client] a copy that authenticates with the bearer token, or the client itself
    # @example Add a filtered stream rule, which takes app-only authentication
    #   client.app_only.post("tweets/search/stream/rules", {add: [{value: "ruby"}]})
    def app_only
      case authenticator
      when OAuth1Authenticator then app_only_copy
      else self
      end
    end

    private

    # The app-only copy of the client, kept until its credentials or settings change
    # @api private
    # @return [Client] the copy
    def app_only_copy
      source = {**credentials, **settings}
      @app_only&.[](source) ||
        copy(access_token: nil, access_token_secret: nil, bearer_token: app_bearer_token).tap { |app_client| @app_only = {source => app_client} }
    end

    # Replace some credentials, keeping the tokens of the last refresh
    #
    # The authenticator is built once, after every credential is replaced.
    #
    # @api private
    # @param changes [Hash{Symbol => Object}] the credentials to change
    # @return [void]
    def replace_credentials(**changes)
      initialize_credentials(**credentials, **changes)
      initialize_authenticator
    end

    # The app-only bearer token, fetched once with the API key and secret
    # @api private
    # @return [String] the bearer token
    def app_bearer_token
      bearer_token || fetched_app_bearer_token
    end

    # The app-only bearer token this client fetched, fetching it the first time
    # @api private
    # @return [String] the bearer token
    def fetched_app_bearer_token
      key = api_key #: String
      secret = api_key_secret #: String
      @app_bearer_token ||= AppOnlyAuthenticator.new(api_key: key, api_key_secret: secret, connection: @connection).bearer_token
    end

    # The credentials, as initialize accepts them
    # @api private
    # @return [Hash{Symbol => String, nil}] the credentials
    def credentials
      {api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:,
       refresh_token:, expires_at:}
    end

    # Initialize credential instance variables
    # @api private
    # @return [void]
    def initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:,
      client_id:, client_secret:, refresh_token:, expires_at:)
      CredentialValidator.validate_expires_at!(expires_at)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
      @bearer_token = bearer_token
      @client_id = client_id
      @client_secret = client_secret
      @refresh_token = refresh_token
      @expires_at = expires_at
    end

    # Initialize the appropriate authenticator based on available credentials
    # @api private
    # @return [Authenticator] the authenticator of the first complete set of credentials, or one that sends none
    def initialize_authenticator
      @app_bearer_token = nil
      @authenticator = oauth1_authenticator || oauth2_authenticator || bearer_authenticator || app_only_authenticator ||
        Authenticator.new
    end

    # Build an OAuth 1.0a authenticator if credentials are available
    # @api private
    # @return [OAuth1Authenticator, nil] the OAuth 1.0a authenticator or nil
    def oauth1_authenticator
      access_token = @access_token
      return unless api_key && api_key_secret && access_token && access_token_secret

      OAuth1Authenticator.new(api_key:, api_key_secret:, access_token:, access_token_secret:)
    end

    # Build an app-only authenticator on the client's connection, given API keys
    # @api private
    # @return [AppOnlyAuthenticator, nil] the app-only authenticator or nil
    def app_only_authenticator
      return unless api_key && api_key_secret

      AppOnlyAuthenticator.new(api_key:, api_key_secret:, connection: @connection)
    end

    # Build a bearer token authenticator if credentials are available
    # @api private
    # @return [BearerTokenAuthenticator, nil] the bearer token authenticator or nil
    def bearer_authenticator
      return unless bearer_token

      BearerTokenAuthenticator.new(bearer_token:)
    end
  end
end
