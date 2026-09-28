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
    # bearer token of an app beside its API key and secret. A client never changes the credentials it was
    # built with, so this runs once, when the client is built.
    #
    # @api private
    module CredentialValidator
      extend self

      # The message of the error raised for credentials that do not form a complete set
      INCOMPLETE_CREDENTIALS = "The credentials given do not form a complete set. Pass api_key, api_key_secret, " \
        "access_token, and access_token_secret for OAuth 1.0a; client_id, access_token, and refresh_token, with the " \
        "client_secret of a confidential client, for OAuth 2.0; bearer_token for a bearer token, such as an OAuth 2.0 " \
        "access token that is not refreshed; or api_key and api_key_secret to authenticate as the app. Leave out any " \
        "credential of a set that is not complete"
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
        "epoch, or nil if it is not known"
      private_constant :INVALID_EXPIRES_AT

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
      # @raise [ArgumentError] if a credential is an empty String, or one of whitespace alone, or if the expiration
      #   time is neither a Time nor nil
      # @example Check the credentials of a client
      #   X::Core::CredentialValidator.validate_values!(bearer_token: "", expires_at: nil)
      def validate_values!(credentials)
        credentials.each do |name, value|
          case value
          when String then raise ArgumentError, format(EMPTY_CREDENTIAL, name) unless value.match?(/\S/)
          end
        end
        validate_expires_at!(credentials[:expires_at])
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

      # Raise for credentials that do not form a complete set
      #
      # @api private
      # @param credentials [Hash{Symbol => String, Time, nil}] the credentials, as Client#initialize accepts them
      # @return [void]
      # @raise [ArgumentError] if a credential belongs to no complete set
      # @example Check the credentials of a client
      #   X::Core::CredentialValidator.validate!(api_key: "key")
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
end
