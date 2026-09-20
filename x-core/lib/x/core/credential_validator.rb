module X
  # Checks that the credentials of a new client form complete sets
  #
  # A client authenticates with the first complete set of credentials it has, and ignores the rest. Credentials that
  # form no set would send requests without credentials, an access token without the rest of its set would
  # authenticate as the app, or with a bearer token, rather than as the user it belongs to, and any other credential
  # of a set that is not complete, such as a client ID beside a bearer token, is a mistake that a client would
  # otherwise hide. So every credential must belong to a complete set. A client may hold several, such as the
  # bearer token of an app beside its API key and secret. A setter changes one credential at a time, and checks
  # nothing, since the set it changes is complete only once every setter has been called.
  #
  # @api private
  module CredentialValidator
    extend self

    # The message of the error raised for credentials that do not form a complete set
    INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
      "access_token, and access_token_secret for OAuth 1.0a; client_id, access_token, and refresh_token, with the " \
      "client_secret of a confidential client, for OAuth 2.0; bearer_token for a bearer token, such as an OAuth 2.0 " \
      "access token that is not refreshed; or api_key and api_key_secret to authenticate as the app. Leave out any " \
      "credential of a set that is not complete".freeze
    private_constant :INCOMPLETE_CREDENTIALS

    # The credentials of each set: OAuth 1.0a, OAuth 2.0 for a confidential and for a public client, a bearer token,
    # and the app's API key and secret
    CREDENTIAL_SETS = [
      %i[api_key api_key_secret access_token access_token_secret],
      %i[client_id client_secret access_token refresh_token],
      %i[client_id access_token refresh_token],
      %i[bearer_token],
      %i[api_key api_key_secret]
    ].freeze

    # The message of the error raised for an expiration time that is not a Time
    INVALID_EXPIRES_AT = "expires_at must be a Time, such as Time.at(seconds) for a time stored as seconds since the " \
      "epoch, or nil if it is not known".freeze
    private_constant :INVALID_EXPIRES_AT

    # The message of the error raised for a credential that is an empty String
    EMPTY_CREDENTIAL = "%s is empty. Pass the credential, or leave it out, since an empty one authenticates nothing".freeze
    private_constant :EMPTY_CREDENTIAL

    # Raise for an empty credential, or an expiration time that is not a Time
    #
    # An environment variable that is not set is often read as an empty String, as ENV.fetch("X_BEARER_TOKEN", "")
    # reads it, which would send an Authorization header that authenticates nothing, for the API to refuse.
    #
    # @api private
    # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
    # @return [void]
    # @raise [ArgumentError] if a credential is an empty String, or one of whitespace alone, or if the expiration
    #   time is neither a Time nor nil
    # @example Check the credentials of a client
    #   X::CredentialValidator.validate_values!(bearer_token: "", expires_at: nil)
    def validate_values!(credentials)
      credentials.each do |name, value|
        case value
        when String then raise ArgumentError, format(EMPTY_CREDENTIAL, name) unless value.match?(/\S/)
        end
      end
      validate_expires_at!(credentials.fetch(:expires_at))
    end

    # Raise for an expiration time that is not a Time
    #
    # A token refresh compares the expiration time with the current time before every request, which fails for a time
    # stored as a number or a String.
    #
    # @api private
    # @param expires_at [Object] the expiration time
    # @return [void]
    # @raise [ArgumentError] if the expiration time is neither a Time nor nil
    # @example Check an expiration time
    #   X::CredentialValidator.validate_expires_at!(Time.now + 7200)
    def validate_expires_at!(expires_at)
      raise ArgumentError, INVALID_EXPIRES_AT unless expires_at.nil? || expires_at.is_a?(Time)
    end

    # Raise for credentials that do not form a complete set
    #
    # @api private
    # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
    # @return [void]
    # @raise [ArgumentError] if a credential belongs to no complete set
    # @example Check the credentials of a client
    #   X::CredentialValidator.validate!(api_key: "key")
    def validate!(credentials)
      raise ArgumentError, INCOMPLETE_CREDENTIALS if incomplete?(credentials)
    end

    private

    # Check whether a credential was given that belongs to no complete set
    #
    # The expiration time is no credential, so it is allowed beside any.
    #
    # @api private
    # @param credentials [Hash{Symbol => String, Time, nil}] the credentials
    # @return [Boolean] true if the credentials do not form complete sets
    def incomplete?(credentials)
      given = credentials.except(:expires_at).compact.keys
      complete = CREDENTIAL_SETS.select { |set| (set - given).empty? }
      (given - complete.flatten).any?
    end
  end
end
