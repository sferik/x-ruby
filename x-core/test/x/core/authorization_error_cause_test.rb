# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The cause of an AuthorizationError is the error of x-core it was raised in rescue of, and never the error of
  # simple_oauth it was built from
  class AuthorizationErrorCauseTest < Minitest::Test
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover OAuth2Authorization

    USERS_ME = "https://api.x.com/2/users/me"
    TWEET = "https://api.x.com/2/tweets/1"

    def test_a_refused_refresh_of_a_rejected_token_is_caused_by_the_rejection
      refuse_token(OAUTH2_TOKEN_URL)
      stub_request(:get, USERS_ME).to_return(status: 401)
      error = assert_raises(AuthorizationError) { Client.new(**test_oauth2_credentials).get("users/me") }

      assert_instance_of Unauthorized, error.cause
      assert_equal USERS_ME, error.cause.uri.to_s
    end

    def test_a_refused_refresh_of_an_expired_token_has_no_cause
      refuse_token(OAUTH2_TOKEN_URL)
      error = assert_raises(AuthorizationError) { Client.new(**test_oauth2_credentials, expires_at: Time.now - 1).get("users/me") }

      assert_nil error.cause
    end

    def test_a_refused_fetch_in_place_of_a_rejected_app_only_token_is_caused_by_the_rejection
      refuse_token(APP_ONLY_TOKEN_URL)
      stub_request(:get, TWEET).to_return(status: 401)
      error = assert_raises(AuthorizationError) do
        Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "GIVEN").get("tweets/1")
      end

      assert_instance_of Unauthorized, error.cause
    end

    def test_a_refused_fetch_of_an_app_only_token_has_no_cause
      refuse_token(APP_ONLY_TOKEN_URL)
      error = assert_raises(AuthorizationError) { Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET).get("tweets/1") }

      assert_nil error.cause
    end

    def test_a_refused_authorization_code_has_no_cause
      refuse_token(OAUTH2_TOKEN_URL)
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/callback", state: "STATE")
      error = assert_raises(AuthorizationError) { authorization.tokens("state=STATE&code=CODE") }

      assert_nil error.cause
    end

    private

    # Have a token endpoint refuse the grant it is sent
    def refuse_token(url)
      stub_request(:post, url).to_return(status: 400, body: {error: "invalid_grant"}.to_json)
    end
  end
end
