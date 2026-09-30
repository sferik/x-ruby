# frozen_string_literal: true

module X
  module Core
    # The authentication credentials of a client, which it reads but never changes, included into Client
    #
    # A client is built with the credentials it keeps for as long as it lives. {Client#with} derives a client whose
    # credentials differ, rather than replacing the ones a client holds, so that a request never signs with a mix of
    # old and new credentials.
    #
    # @api private
    module ClientCredentials
      # The API key for OAuth 1.0a authentication
      # @api public
      # @return [String, nil] the API key for OAuth 1.0a authentication
      # @example Get the API key
      #   client.api_key
      attr_reader :api_key

      # The OAuth 2.0 client ID
      # @api public
      # @return [String, nil] the OAuth 2.0 client ID
      # @example Get the client ID
      #   client.client_id
      attr_reader :client_id

      private

      # The API key secret for OAuth 1.0a authentication
      #
      # It is private, as {Client#inspect} hides it, so that code that reflects over a client never reads a secret
      # out of it. {Client#with} carries it to a copy without revealing it, and the authenticator of a client holds
      # the credentials it signs with.
      #
      # @api private
      # @return [String, nil] the API key secret for OAuth 1.0a authentication
      attr_reader :api_key_secret

      # The access token secret for OAuth 1.0a authentication
      #
      # It is private for the reason {#api_key_secret} is.
      #
      # @api private
      # @return [String, nil] the access token secret for OAuth 1.0a authentication
      attr_reader :access_token_secret

      # The bearer token for authentication
      #
      # It is private for the reason {#api_key_secret} is.
      #
      # @api private
      # @return [String, nil] the bearer token for authentication
      attr_reader :bearer_token

      # The OAuth 2.0 client secret
      #
      # It is private for the reason {#api_key_secret} is.
      #
      # @api private
      # @return [String, nil] the OAuth 2.0 client secret
      attr_reader :client_secret

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

      # Refuse an authenticator beside credentials, and credentials of no complete set
      # @api private
      # @param authenticator [Authenticator, nil] the authenticator the client was given, or nil
      # @return [void]
      # @raise [ArgumentError] if the authenticator is not an Authenticator, or is given beside credentials
      # @raise [ArgumentError] if the credentials do not form complete sets
      def validate_credentials!(authenticator)
        CredentialValidator.validate_authenticator!(authenticator, credentials)
        CredentialValidator.validate!(credentials)
      end

      # Take the authenticator the client was given, or build one of its credentials
      #
      # The authenticator built is the one of the first complete set of credentials held, and a client that holds no
      # complete set sends its requests without credentials. Taking an authenticator binds it to the connection of the
      # client and reports its refreshes to the client, so the client checks the authenticator, and every other
      # option, before it takes it, and a client that raises leaves the authenticator as it was.
      #
      # @api private
      # @param given [Authenticator, nil] the authenticator the client was given, or nil to build one
      # @return [void]
      def initialize_authenticator(given)
        @given_authenticator = given
        @authenticator = given ? take(given) : built_authenticator
      end

      # Build the authenticator of the first complete set of credentials held
      # @api private
      # @return [Authenticator] the authenticator, which sends no credentials when no set is complete
      def built_authenticator
        oauth1_authenticator || oauth2_authenticator || app_only_authenticator || bearer_authenticator || Authenticator.new
      end

      # The options of a copy of the client, beside the credentials it is built with
      #
      # An authenticator given to the copy replaces the credentials of the client, a credential given to it replaces
      # the authenticator the client was given, and a copy given neither shares that authenticator. An expiration
      # time is no credential, and is refused beside an authenticator, as it is when a client is built.
      #
      # @api private
      # @param options [Hash{Symbol => Object}] the options the copy is given
      # @return [Hash{Symbol => Object}] the options, beside the credentials or the authenticator the copy shares
      def with_credentials(options)
        given = @given_authenticator
        return {authenticator: given, **options} if given && !options.keys.intersect?(credentials.except(:expires_at).keys)

        options[:authenticator] ? options : {**credentials, **options}
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
      #
      # A bearer token given beside them is sent until the API rejects it, and one is fetched with them in its place.
      #
      # @api private
      # @return [AppOnlyAuthenticator, nil] the app-only authenticator or nil
      def app_only_authenticator
        return unless api_key && api_key_secret

        AppOnlyAuthenticator.new(api_key:, api_key_secret:, bearer_token:).__send__(:token_requests_over, @connection, base_url)
      end

      # Build a bearer token authenticator if credentials are available
      # @api private
      # @return [BearerTokenAuthenticator, nil] the bearer token authenticator or nil
      def bearer_authenticator
        return unless bearer_token

        BearerTokenAuthenticator.new(bearer_token:)
      end
    end
    private_constant :ClientCredentials
  end
end
