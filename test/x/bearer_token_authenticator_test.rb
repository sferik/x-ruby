require_relative "../test_helper"

module X
  # Tests for X::BearerTokenAuthenticator class
  class BearerTokenAuthenticatorTest < Minitest::Test
    cover BearerTokenAuthenticator

    def setup
      @authenticator = BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_initialize
      assert_equal TEST_BEARER_TOKEN, @authenticator.bearer_token
    end

    def test_header
      assert_kind_of Hash, @authenticator.header(nil)
      assert_equal "Bearer #{TEST_BEARER_TOKEN}", @authenticator.header(nil)["Authorization"]
    end
  end
end
