module X
  # Mixin for client authentication credentials
  # @api private
  module ClientCredentials
    # The message of the error raised for a change to a credential a client does not take, as Ruby words the error
    # that building a client from one raised before
    UNKNOWN_CREDENTIAL = "unknown keyword: %s".freeze
    private_constant :UNKNOWN_CREDENTIAL

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

    # Set the API key for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key [String, nil] the API key for OAuth 1.0a authentication, or nil to clear it
    # @return [void]
    # @example Set the API key
    #   client.api_key = "new_key"
    def api_key=(api_key)
      replace_credentials(api_key:)
    end

    # Set the API key secret for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key_secret [String, nil] the API key secret for OAuth 1.0a authentication, or nil to clear it
    # @return [void]
    # @example Set the API key secret
    #   client.api_key_secret = "new_secret"
    def api_key_secret=(api_key_secret)
      replace_credentials(api_key_secret:)
    end

    # Set the access token for OAuth authentication
    #
    # @api public
    # @param access_token [String, nil] the access token for OAuth authentication, or nil to clear it
    # @return [void]
    # @example Set the access token
    #   client.access_token = "new_token"
    def access_token=(access_token)
      replace_credentials(access_token:)
    end

    # Set the access token secret for OAuth 1.0a authentication
    #
    # @api public
    # @param access_token_secret [String, nil] the access token secret for OAuth 1.0a authentication, or nil to clear it
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
    # @param bearer_token [String, nil] the bearer token for authentication, or nil to clear it
    # @return [void]
    # @example Set the bearer token
    #   client.bearer_token = "new_token"
    def bearer_token=(bearer_token)
      replace_credentials(bearer_token:)
    end

    # Set the OAuth 2.0 client ID
    #
    # @api public
    # @param client_id [String, nil] the OAuth 2.0 client ID, or nil to clear it
    # @return [void]
    # @example Set the client ID
    #   client.client_id = "new_id"
    def client_id=(client_id)
      replace_credentials(client_id:)
    end

    # Set the OAuth 2.0 client secret
    #
    # @api public
    # @param client_secret [String, nil] the OAuth 2.0 client secret, or nil to clear it
    # @return [void]
    # @example Set the client secret
    #   client.client_secret = "new_secret"
    def client_secret=(client_secret)
      replace_credentials(client_secret:)
    end

    # Set the OAuth 2.0 refresh token
    #
    # @api public
    # @param refresh_token [String, nil] the OAuth 2.0 refresh token, or nil to clear it
    # @return [void]
    # @example Set the refresh token
    #   client.refresh_token = "new_token"
    def refresh_token=(refresh_token)
      replace_credentials(refresh_token:)
    end

    # Set the time the OAuth 2.0 access token expires
    #
    # The first request after that time, less a buffer for clock skew, refreshes the token. The copies of a client
    # that share its OAuth 2.0 authenticator share the expiration time, so setting it on one sets it for each.
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
    # The credentials are checked as initialize checks them, before any of them is replaced, so a change the client
    # would refuse leaves it as it was.
    #
    # @api public
    # @param changes [Hash{Symbol => String, Time, nil}] the credentials to change, as initialize accepts them
    # @return [void]
    # @raise [ArgumentError] if a change names a credential a client does not take
    # @raise [ArgumentError] if the credentials, once changed, do not form a complete set, as initialize would raise,
    #   which leaves the client as it was
    # @example Rotate an OAuth 1.0a access token
    #   client.update_credentials(access_token: "new_token", access_token_secret: "new_secret")
    # @example Stop sending credentials
    #   client.update_credentials(bearer_token: nil)
    def update_credentials(**changes)
      held = credentials
      unknown = changes.keys - held.keys
      raise ArgumentError, format(UNKNOWN_CREDENTIAL, unknown.map(&:inspect).join(", ")) unless unknown.empty?

      updated = held.merge(changes)
      CredentialValidator.validate_values!(updated)
      CredentialValidator.validate!(updated)
      replace_credentials(**changes)
    end

    private

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

    # The credentials, as initialize accepts them
    # @api private
    # @return [Hash{Symbol => String, nil}] the credentials
    def credentials = {api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:, refresh_token:, expires_at:}

    # Initialize credential instance variables
    # @api private
    # @return [void]
    def initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:,
      client_id:, client_secret:, refresh_token:, expires_at:)
      CredentialValidator.validate_values!(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:, client_id:, client_secret:, refresh_token:, expires_at:)
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
    #
    # A client that no longer holds the OAuth 2.0 authenticator it shared leaves the clients a refresh reports to, so
    # that its on_token_refresh never receives the tokens of credentials it has replaced.
    #
    # @api private
    # @return [void]
    def initialize_authenticator
      @app_bearer_token = nil
      previous = @authenticator
      clients = @token_refresh_clients
      @authenticator = oauth1_authenticator || oauth2_authenticator || bearer_authenticator || app_only_authenticator ||
        Authenticator.new
      clients&.delete(self) unless @authenticator.equal?(previous)
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
