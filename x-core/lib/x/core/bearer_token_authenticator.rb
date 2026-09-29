# frozen_string_literal: true

require_relative "authenticator"
require_relative "credential_validator"

module X
  # Authenticator for Bearer token authentication
  # @api public
  class BearerTokenAuthenticator < Authenticator
    # Initialize a new BearerTokenAuthenticator
    #
    # @api public
    # @param bearer_token [String] the bearer token for authentication
    # @return [BearerTokenAuthenticator] a new instance
    # @raise [ArgumentError] if the bearer token is nil or empty
    # @example Create a new bearer token authenticator
    #   authenticator = X::BearerTokenAuthenticator.new(bearer_token: "token")
    def initialize(bearer_token:)
      Core::CredentialValidator.validate_required!({bearer_token:})
      @bearer_token = bearer_token
    end

    # Generate the authentication header for a request
    #
    # @api public
    # @param _request [#method, #uri, #body, #[], nil] the request, which a bearer token does not sign
    # @return [Hash{String => String}] the authentication header with bearer token
    # @example Generate a bearer authentication header
    #   authenticator.header(request)
    def header(_request)
      {AUTHENTICATION_HEADER => "Bearer #{bearer_token}"}
    end

    private

    # The bearer token, which authenticates a request
    # @api private
    # @return [String] the bearer token
    # @example Authenticate with the bearer token
    #   bearer_token
    attr_reader :bearer_token
  end
end
