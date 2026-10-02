# frozen_string_literal: true

require_relative "authenticator"

module X
  module Core
    # Checks that the credentials of a new client form complete sets
    #
    # A client authenticates with the first complete set of credentials it has, and ignores the rest. Credentials that
    # form no set would send requests without credentials, an access token without the rest of its set would
    # authenticate as the app, or with a bearer token, rather than as the user it belongs to, and any other credential
    # of a set that is not complete, such as a client ID beside a bearer token, is a mistake that a client would
    # otherwise hide. So every credential must belong to a complete set. A client may hold several, such as the
    # bearer token of an app beside its API key and secret, but not OAuth 2.0 credentials beside OAuth 1.0a ones, which
    # share the access token, and which it authenticates with first, so that the OAuth 2.0 credentials would go unused.
    # A client never changes the credentials it was built with, so this runs once, when the client is built.
    #
    # @api private
    module CredentialValidator
      extend self

      # The message of the error raised for credentials that do not form a complete set
      INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
        "access_token, and access_token_secret for OAuth 1.0a; client_id and access_token, with the refresh_token " \
        "that refreshes it and the client_secret of a confidential client, for OAuth 2.0; bearer_token for the app's " \
        "bearer token; or api_key and api_key_secret to authenticate as the app. Leave out any credential of a set " \
        "that is not complete"
      private_constant :INCOMPLETE_CREDENTIALS

      # The credentials of each set: OAuth 1.0a, OAuth 2.0 for a confidential and for a public client, with a refresh
      # token and without one, as an authorization without offline.access issues them, a bearer token, and the app's
      # API key and secret
      CREDENTIAL_SETS = [
        %i[api_key api_key_secret access_token access_token_secret],
        %i[client_id client_secret access_token refresh_token],
        %i[client_id access_token refresh_token],
        %i[client_id client_secret access_token],
        %i[client_id access_token],
        %i[bearer_token],
        %i[api_key api_key_secret]
      ].freeze

      # The credentials a client authenticates with before OAuth 2.0 credentials, when it holds both
      OAUTH1_CREDENTIALS = CREDENTIAL_SETS.first
      # The credentials of the least set of OAuth 2.0, which an expiration time is the expiration time of the token of
      OAUTH2_CREDENTIALS = CREDENTIAL_SETS.fetch(4)
      # The credentials of OAuth 2.0 that no other set holds, which a client that authenticates with OAuth 1.0a ignores
      OAUTH2_ONLY_CREDENTIALS = %i[client_id client_secret refresh_token].freeze
      private_constant :OAUTH1_CREDENTIALS, :OAUTH2_CREDENTIALS, :OAUTH2_ONLY_CREDENTIALS

      # The message of the error raised for OAuth 2.0 credentials the client would leave unused
      UNUSED_OAUTH2_CREDENTIALS = "%s are OAuth 2.0 credentials, which a client given OAuth 1.0a credentials would " \
        "leave unused, since it authenticates with those, and the access_token they share is the OAuth 1.0a one. Pass " \
        "the credentials of one or the other"
      private_constant :UNUSED_OAUTH2_CREDENTIALS

      # The message of the error raised for an expiration time the client would leave unused
      UNUSED_EXPIRES_AT = "expires_at is the time an OAuth 2.0 access token expires, so it is given beside the " \
        "client_id and access_token the client authenticates with, rather than beside OAuth 1.0a credentials, a " \
        "bearer_token, an api_key and api_key_secret, or none, which would leave it unused. Leave it out"
      private_constant :UNUSED_EXPIRES_AT

      # The message of the error raised for an expiration time that is not a Time
      INVALID_EXPIRES_AT = "expires_at must be a Time, such as Time.at(seconds) for a time stored as seconds since the " \
        "epoch, or nil if it is not known"
      private_constant :INVALID_EXPIRES_AT

      # The message of the error raised for scopes the client would leave unused
      UNUSED_SCOPES = "scopes are the scopes X granted an OAuth 2.0 access token, so they are given beside the " \
        "client_id and access_token the client authenticates with, rather than beside OAuth 1.0a credentials, a " \
        "bearer_token, an api_key and api_key_secret, or none, which would leave them unused. Leave them out"
      private_constant :UNUSED_SCOPES

      # The message of the error raised for scopes that are not an Array of scopes
      INVALID_SCOPES = "scopes must be an Array of Strings that each name a scope, such as %w[tweet.read users.read], " \
        "or nil if they are not known"
      private_constant :INVALID_SCOPES

      # A scope, which OAuth 2.0 names with printable characters other than a space, a quote, and a backslash
      SCOPE = /\A[\x21\x23-\x5B\x5D-\x7E]+\z/
      private_constant :SCOPE

      # The message of the error raised for a credential that is an empty String
      EMPTY_CREDENTIAL = "%s is empty. Pass the credential, or leave it out, since an empty one authenticates nothing"
      private_constant :EMPTY_CREDENTIAL

      # The message raised for a credential an authenticator requires that is nil or empty
      MISSING_CREDENTIAL = "%s is nil or empty. Pass the credential, which the authenticator cannot authenticate without"
      private_constant :MISSING_CREDENTIAL

      # The message of the error raised for an authenticator that is not one
      NOT_AN_AUTHENTICATOR = "authenticator must be an X::Authenticator, such as an X::OAuth2Authenticator, or nil, " \
        "not a %s"
      private_constant :NOT_AN_AUTHENTICATOR

      # The message of the error raised for an authenticator given beside credentials
      AUTHENTICATOR_AND_CREDENTIALS = "An authenticator holds the credentials it authenticates with, so it cannot be " \
        "given beside %s. Pass the authenticator, or the credentials, and leave out the other"
      private_constant :AUTHENTICATOR_AND_CREDENTIALS

      # Raise for an empty credential, or an expiration time that is not a Time
      #
      # An environment variable that is not set is often read as an empty String, as ENV.fetch("X_BEARER_TOKEN", "")
      # reads it, which would send an Authorization header that authenticates nothing, for the API to refuse.
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
      # @return [void]
      # @raise [ArgumentError] if a credential is an empty String, or one of whitespace alone, if the expiration time
      #   is neither a Time nor nil, or if the scopes are neither an Array of scopes nor nil
      # @example Check the credentials of a client
      #   X::Core::CredentialValidator.validate_values!(bearer_token: "", expires_at: nil)
      def validate_values!(credentials)
        credentials.each do |name, value|
          case value
          when String then raise ArgumentError, format(EMPTY_CREDENTIAL, name) unless value.match?(/\S/)
          end
        end
        validate_expires_at!(credentials[:expires_at])
        validate_scopes!(credentials[:scopes])
      end

      # Raise for a credential an authenticator requires that is nil or empty
      #
      # An authenticator is given the credentials it authenticates with, so each is required, and one given as nil,
      # as ENV[] reads a variable that is not set, or as an empty String, would authenticate nothing. The others it
      # takes beside them are checked as {#validate_values!} checks those of a client.
      #
      # @api private
      # @param required [Hash{Symbol => String, nil}] the credentials the authenticator requires, by the names it
      #   takes them by
      # @param others [Hash{Symbol => String, Time, nil}] the credentials and expiration time it takes beside them
      # @return [void]
      # @raise [ArgumentError] if a credential required is nil, an empty String, or one of whitespace alone
      # @raise [ArgumentError] if another credential is empty, or the expiration time is neither a Time nor nil
      # @example Check the credential of a bearer token authenticator
      #   X::Core::CredentialValidator.validate_required!({bearer_token: ENV["X_BEARER_TOKEN"]})
      def validate_required!(required, others = {})
        required.each { |name, value| raise ArgumentError, format(MISSING_CREDENTIAL, name) unless value.to_s.match?(/\S/) }
        validate_values!(others)
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
      #   X::Core::CredentialValidator.validate_expires_at!(Time.now + 7200)
      def validate_expires_at!(expires_at)
        raise ArgumentError, INVALID_EXPIRES_AT unless expires_at.nil? || expires_at.is_a?(Time)
      end

      # Raise for scopes that are not an Array of scopes
      #
      # @api private
      # @param scopes [Object] the scopes
      # @return [void]
      # @raise [ArgumentError] if the scopes are neither an Array of Strings that each name a scope nor nil
      # @example Check scopes
      #   X::Core::CredentialValidator.validate_scopes!(%w[tweet.read users.read])
      def validate_scopes!(scopes)
        raise ArgumentError, INVALID_SCOPES unless scopes.nil? || scopes?(scopes)
      end

      # Check whether scopes are an Array of Strings that each name a scope
      #
      # @api private
      # @param scopes [Object] the scopes
      # @return [Boolean] true if the scopes are an Array of Strings that each name a scope
      # @example Check scopes
      #   X::Core::CredentialValidator.scopes?(%w[tweet.read users.read]) # => true
      def scopes?(scopes) = scopes.is_a?(Array) && scopes.all? { |scope| scope.is_a?(String) && SCOPE.match?(scope) }

      # The scopes as the tokens, an authenticator, or a client holds them
      #
      # They are frozen, the Array and each String, apart from those given, so that the caller that gave them can
      # change neither what the client holds nor what save_tokens is passed.
      #
      # @api private
      # @param scopes [Array<String>, nil] the scopes, which validate_scopes! accepted
      # @return [Array<String>, nil] the scopes, frozen, or nil for none
      # @example Hold scopes
      #   X::Core::CredentialValidator.frozen_scopes(%w[tweet.read]) # => ["tweet.read"]
      def frozen_scopes(scopes) = scopes&.map { |scope| -scope }.freeze

      # Raise for an authenticator that is not one, or that is given beside credentials
      #
      # A client given an authenticator authenticates with it alone, so a credential given beside it, the expiration
      # time of an OAuth 2.0 access token included, which an OAuth2Authenticator is built with, would go unused. The
      # error names the class of something that is not an authenticator, rather than inspect it, since a Hash of
      # credentials passed in its place would show them.
      #
      # @api private
      # @param authenticator [Object] the authenticator, or nil for none
      # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
      # @return [void]
      # @raise [ArgumentError] if the authenticator is neither an Authenticator nor nil, or is given beside a
      #   credential
      # @example Check the authenticator of a client
      #   X::Core::CredentialValidator.validate_authenticator!(authenticator, bearer_token: nil)
      def validate_authenticator!(authenticator, credentials)
        return if authenticator.nil?
        raise ArgumentError, format(NOT_AN_AUTHENTICATOR, authenticator.class) unless authenticator.is_a?(Authenticator)

        given = credentials.compact.keys
        raise ArgumentError, format(AUTHENTICATOR_AND_CREDENTIALS, given.join(", ")) unless given.empty?
      end

      # Raise for incomplete credentials, or ones that leave others unused
      #
      # A client given OAuth 1.0a credentials authenticates with them, so OAuth 2.0 credentials given beside them, which
      # would share their access token, raise. An expiration time and scopes are those of an OAuth 2.0 access token,
      # which a client reads only when it authenticates with OAuth 2.0 credentials, so either given to a client that
      # authenticates otherwise raises, as it does beside an authenticator.
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, Array<String>, nil}] the credentials, as Client#initialize
      #   accepts them
      # @return [void]
      # @raise [ArgumentError] if a credential belongs to no complete set, OAuth 2.0 credentials are given beside
      #   OAuth 1.0a ones, or an expiration time or scopes are given to a client that does not authenticate with OAuth
      #   2.0 credentials
      # @example Check the credentials of a client
      #   X::Core::CredentialValidator.validate!(api_key: "key")
      def validate!(credentials)
        raise ArgumentError, INCOMPLETE_CREDENTIALS if incomplete?(credentials)

        unused = unused_oauth2_credentials(credentials)
        raise ArgumentError, format(UNUSED_OAUTH2_CREDENTIALS, unused.join(", ")) unless unused.empty?
        raise ArgumentError, UNUSED_EXPIRES_AT if unused?(credentials, :expires_at)
        raise ArgumentError, UNUSED_SCOPES if unused?(credentials, :scopes)
      end

      private

      # Check whether a credential was given that belongs to no complete set
      #
      # The expiration time and scopes are no credentials, so they belong to no set, and unused? checks them.
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, Array<String>, nil}] the credentials
      # @return [Boolean] true if the credentials do not form complete sets
      def incomplete?(credentials)
        given = credentials.except(:expires_at, :scopes).compact.keys
        complete = CREDENTIAL_SETS.select { |set| (set - given).empty? }
        (given - complete.flatten).any?
      end

      # The OAuth 2.0 credentials given beside OAuth 1.0a ones, which would go unused
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, Array<String>, nil}] the credentials
      # @return [Array<Symbol>] the names of the OAuth 2.0 credentials given, or none when OAuth 1.0a ones are not
      def unused_oauth2_credentials(credentials)
        given = credentials.compact.keys
        (OAUTH1_CREDENTIALS - given).empty? ? OAUTH2_ONLY_CREDENTIALS & given : []
      end

      # Check whether expires_at or scopes were given that the client would leave unused
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, Array<String>, nil}] the credentials
      # @param name [Symbol] the name of what was given of the access token, expires_at or scopes
      # @return [Boolean] true if it was given, and the client holds no OAuth 2.0 credentials, which validate! refuses
      #   beside OAuth 1.0a ones before it checks this
      def unused?(credentials, name)
        given = credentials.compact.keys
        given.include?(name) && !(OAUTH2_CREDENTIALS - given).empty?
      end
    end
    private_constant :CredentialValidator
  end
end
