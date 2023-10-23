require_relative "authenticator"

module X
  # Handles bearer token authentication
  class BearerTokenAuthenticator < Authenticator
    attr_accessor :bearer_token

    def initialize(bearer_token:) # rubocop:disable Lint/MissingSuper
      @bearer_token = bearer_token
    end

    def header(_request)
      {"Authorization" => "Bearer #{bearer_token}"}
    end
  end
end
