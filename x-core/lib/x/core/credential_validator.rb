require_relative "app_only_authenticator"
require_relative "bearer_token_authenticator"
require_relative "oauth1_authenticator"
require_relative "oauth2_authenticator"

module X
  # Checks that the credentials of a new client form a complete set
  #
  # A client authenticates with the first complete set of credentials it has, and a setter changes one credential
  # at a time, so a client keeps its authenticator until a set is complete again. A new client has no
  # authenticator to keep: credentials that form no set would send requests without credentials, and an access
  # token without the rest of its set would authenticate as the app, or with a bearer token, rather than as the
  # user it belongs to.
  #
  # @api private
  module CredentialValidator
    extend self

    # The message of the error raised for credentials that do not form a complete set
    INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
      "access_token, and access_token_secret for OAuth 1.0a; client_id, access_token, and refresh_token, with the " \
      "client_secret of a confidential client, for OAuth 2.0; bearer_token for a bearer token, such as an OAuth 2.0 " \
      "access token that is not refreshed; or api_key and api_key_secret to authenticate as the app".freeze

    # Raise for credentials that do not form a complete set
    #
    # @api private
    # @param authenticator [Authenticator] the authenticator built from the credentials
    # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
    # @return [void]
    # @raise [ArgumentError] if the credentials do not form a complete set
    # @example Check the credentials of a client
    #   X::CredentialValidator.validate!(client.authenticator, api_key: "key")
    def validate!(authenticator, credentials)
      raise ArgumentError, INCOMPLETE_CREDENTIALS if incomplete?(authenticator, credentials)
    end

    private

    # Check whether credentials were given that the authenticator does not use
    # @api private
    # @param authenticator [Authenticator] the authenticator built from the credentials
    # @param credentials [Hash{Symbol => String, Time, nil}] the credentials
    # @return [Boolean] true if the credentials do not form a complete set
    def incomplete?(authenticator, credentials)
      case authenticator
      when OAuth1Authenticator, OAuth2Authenticator then false
      when BearerTokenAuthenticator, AppOnlyAuthenticator then !credentials.fetch(:access_token).nil?
      else credentials.except(:expires_at).values.any?
      end
    end
  end
end
