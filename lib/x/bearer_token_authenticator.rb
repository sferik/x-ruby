require_relative "authenticator"

module X
  # Authenticator for Bearer token authentication
  # @api public
  class BearerTokenAuthenticator < Authenticator
    # The bearer token for authentication
    # @api public
    # @return [String] the bearer token
    # @example Get the bearer token
    #   authenticator.bearer_token
    attr_accessor :bearer_token

    # Initialize a new BearerTokenAuthenticator
    #
    # @api public
    # @param bearer_token [String] the bearer token for authentication
    # @return [BearerTokenAuthenticator] a new instance
    # @example Create a new bearer token authenticator
    #   authenticator = X::BearerTokenAuthenticator.new(bearer_token: "token")
    def initialize(bearer_token:)
      @bearer_token = bearer_token
    end

    # Generate the authentication header for a request
    #
    # @api public
    # @param _request [Net::HTTPRequest] the HTTP request
    # @return [Hash{String => String}] the authentication header with bearer token
    # @example Generate a bearer authentication header
    #   authenticator.header(request)
    def header(_request)
      {AUTHENTICATION_HEADER => "Bearer #{bearer_token}"}
    end
  end
end
