require "oauth"
require "forwardable"

module X
  # Handles OAuth authentication
  class Authenticator
    extend Forwardable

    def_delegator :@access_token, :secret, :access_token_secret
    def_delegator :@access_token, :secret=, :access_token_secret=
    def_delegator :@access_token, :token, :access_token
    def_delegator :@access_token, :token=, :access_token=
    def_delegator :@consumer, :key, :api_key
    def_delegator :@consumer, :key=, :api_key=
    def_delegator :@consumer, :secret, :api_key_secret
    def_delegator :@consumer, :secret=, :api_key_secret=

    def initialize(api_key, api_key_secret, access_token, access_token_secret)
      @consumer = OAuth::Consumer.new(api_key, api_key_secret, site: ClientDefaults::DEFAULT_BASE_URL)
      @access_token = OAuth::Token.new(access_token, access_token_secret)
    end

    def sign!(request)
      @consumer.sign!(request, @access_token)
    end
  end
end
