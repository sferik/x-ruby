require "oauth"
require "forwardable"

module X
  # Handles OAuth and bearer token authentication
  class Authenticator
    extend Forwardable

    attr_accessor :bearer_token

    def_delegator :@access_token, :secret, :access_token_secret
    def_delegator :@access_token, :secret=, :access_token_secret=
    def_delegator :@access_token, :token, :access_token
    def_delegator :@access_token, :token=, :access_token=
    def_delegator :@consumer, :key, :api_key
    def_delegator :@consumer, :key=, :api_key=
    def_delegator :@consumer, :secret, :api_key_secret
    def_delegator :@consumer, :secret=, :api_key_secret=

    def initialize(bearer_token:, api_key:, api_key_secret:, access_token:, access_token_secret:)
      if bearer_token
        @bearer_token = bearer_token
      else
        initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      end
    end

    def sign!(request)
      @consumer.sign!(request, @access_token)
    end

    private

    def initialize_oauth(api_key, api_key_secret, access_token, access_token_secret)
      unless api_key && api_key_secret && access_token && access_token_secret
        raise ArgumentError, "Missing OAuth credentials"
      end

      @consumer = OAuth::Consumer.new(api_key, api_key_secret, site: ClientDefaults::DEFAULT_BASE_URL)
      @access_token = OAuth::Token.new(access_token, access_token_secret)
    end
  end
end
