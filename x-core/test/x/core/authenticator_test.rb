# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AuthenticatorTest < Minitest::Test
    cover Authenticator

    def setup
      @authenticator = Authenticator.new
    end

    def test_header
      assert_equal({}, @authenticator.header(nil))
    end

    def test_credentials_that_name_no_user_have_no_user_id
      assert_nil @authenticator.user_id
      assert_nil BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN).user_id
      assert_nil OAuth2Authenticator.new(**test_oauth2_credentials).user_id
    end

    def test_inspect
      assert_equal "#<X::Authenticator>", @authenticator.inspect
    end
  end
end
