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
    # The access token for OAuth authentication
    # @api public
    # @return [String, nil] the access token for OAuth authentication
    # @example Get the access token
    #   client.access_token
    attr_reader :access_token
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
    # The OAuth 2.0 refresh token
    # @api public
    # @return [String, nil] the OAuth 2.0 refresh token
    # @example Get the refresh token
    #   client.refresh_token
    attr_reader :refresh_token

    # Set the API key for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key [String] the API key for OAuth 1.0a authentication
    # @return [void]
    # @example Set the API key
    #   client.api_key = "new_key"
    def api_key=(api_key)
      @api_key = api_key
      initialize_authenticator
    end

    # Set the API key secret for OAuth 1.0a authentication
    #
    # @api public
    # @param api_key_secret [String] the API key secret for OAuth 1.0a authentication
    # @return [void]
    # @example Set the API key secret
    #   client.api_key_secret = "new_secret"
    def api_key_secret=(api_key_secret)
      @api_key_secret = api_key_secret
      initialize_authenticator
    end

    # Set the access token for OAuth authentication
    #
    # @api public
    # @param access_token [String] the access token for OAuth authentication
    # @return [void]
    # @example Set the access token
    #   client.access_token = "new_token"
    def access_token=(access_token)
      @access_token = access_token
      initialize_authenticator
    end

    # Set the access token secret for OAuth 1.0a authentication
    #
    # @api public
    # @param access_token_secret [String] the access token secret for OAuth 1.0a authentication
    # @return [void]
    # @example Set the access token secret
    #   client.access_token_secret = "new_secret"
    def access_token_secret=(access_token_secret)
      @access_token_secret = access_token_secret
      initialize_authenticator
    end

    # Set the bearer token for authentication
    #
    # @api public
    # @param bearer_token [String] the bearer token for authentication
    # @return [void]
    # @example Set the bearer token
    #   client.bearer_token = "new_token"
    def bearer_token=(bearer_token)
      @bearer_token = bearer_token
      initialize_authenticator
    end

    # Set the OAuth 2.0 client ID
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID
    # @return [void]
    # @example Set the client ID
    #   client.client_id = "new_id"
    def client_id=(client_id)
      @client_id = client_id
      initialize_authenticator
    end

    # Set the OAuth 2.0 client secret
    #
    # @api public
    # @param client_secret [String] the OAuth 2.0 client secret
    # @return [void]
    # @example Set the client secret
    #   client.client_secret = "new_secret"
    def client_secret=(client_secret)
      @client_secret = client_secret
      initialize_authenticator
    end

    # Set the OAuth 2.0 refresh token
    #
    # @api public
    # @param refresh_token [String] the OAuth 2.0 refresh token
    # @return [void]
    # @example Set the refresh token
    #   client.refresh_token = "new_token"
    def refresh_token=(refresh_token)
      @refresh_token = refresh_token
      initialize_authenticator
    end

    private

    # Initialize credential instance variables
    # @api private
    # @return [void]
    def initialize_credentials(api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:,
      client_id:, client_secret:, refresh_token:)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
      @bearer_token = bearer_token
      @client_id = client_id
      @client_secret = client_secret
      @refresh_token = refresh_token
    end

    # Initialize the appropriate authenticator based on available credentials
    # @api private
    # @return [Authenticator] the initialized authenticator
    def initialize_authenticator
      @authenticator = oauth_authenticator || oauth2_authenticator || bearer_authenticator || @authenticator || Authenticator.new
    end

    # Build an OAuth 1.0a authenticator if credentials are available
    # @api private
    # @return [OAuthAuthenticator, nil] the OAuth authenticator or nil
    def oauth_authenticator
      return unless api_key && api_key_secret && access_token && access_token_secret

      OAuthAuthenticator.new(api_key:, api_key_secret:, access_token:, access_token_secret:)
    end

    # Build an OAuth 2.0 authenticator if credentials are available
    # @api private
    # @return [OAuth2Authenticator, nil] the OAuth 2.0 authenticator or nil
    def oauth2_authenticator
      return unless client_id && client_secret && access_token && refresh_token

      OAuth2Authenticator.new(client_id:, client_secret:, access_token:, refresh_token:)
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
