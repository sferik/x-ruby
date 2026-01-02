require_relative "../test_helper"

module X
  TOKEN_URL = "https://#{OAuth2Authenticator::TOKEN_HOST}#{OAuth2Authenticator::TOKEN_PATH}".freeze

  class OAuth2AuthenticatorInitializationTest < Minitest::Test
    cover OAuth2Authenticator

    def test_initialize_with_required_credentials
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_equal TEST_CLIENT_ID, authenticator.client_id
      assert_equal TEST_CLIENT_SECRET, authenticator.client_secret
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end

    def test_initialize_with_expires_at
      expires_at = Time.now + 7200
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      assert_equal expires_at, authenticator.expires_at
    end

    def test_initialize_without_expires_at
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_nil authenticator.expires_at
    end
  end

  class OAuth2AuthenticatorHeaderTest < Minitest::Test
    cover OAuth2Authenticator

    def test_header_returns_bearer_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      header = authenticator.header(nil)

      assert_equal({"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}, header)
    end
  end

  class OAuth2AuthenticatorTokenExpirationTest < Minitest::Test
    cover OAuth2Authenticator

    def test_token_expired_returns_false_when_no_expires_at
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      refute_predicate authenticator, :token_expired?
    end

    def test_token_expired_returns_false_when_not_expired
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now + 3600)

      refute_predicate authenticator, :token_expired?
    end

    def test_token_expired_returns_true_when_expired
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)

      assert_predicate authenticator, :token_expired?
    end

    def test_token_expired_returns_true_at_exact_expiration_time
      now = Time.now
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: now)

      Time.stub :now, now do
        assert_predicate authenticator, :token_expired?
      end
    end

    def test_token_expired_returns_true_at_buffer_boundary
      now = Time.now
      expires_at = now + OAuth2Authenticator::EXPIRATION_BUFFER
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        assert_predicate authenticator, :token_expired?
      end
    end

    def test_token_expired_returns_true_within_buffer
      now = Time.now
      expires_at = now + (OAuth2Authenticator::EXPIRATION_BUFFER - 1)
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        assert_predicate authenticator, :token_expired?
      end
    end

    def test_token_expired_returns_false_just_outside_buffer
      now = Time.now
      expires_at = now + OAuth2Authenticator::EXPIRATION_BUFFER + 1
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        refute_predicate authenticator, :token_expired?
      end
    end
  end

  class OAuth2AuthenticatorRefreshTokenTest < Minitest::Test
    cover OAuth2Authenticator

    def test_refresh_token_sends_correct_content_type
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!
    end

    def test_refresh_token_sends_basic_auth_header
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      expected_auth = "Basic #{Base64.strict_encode64("#{TEST_CLIENT_ID}:#{TEST_CLIENT_SECRET}")}"
      stub_request(:post, TOKEN_URL)
        .with(headers: {"Authorization" => expected_auth})
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!
    end

    def test_refresh_token_sends_correct_request_body
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      expected_body = "grant_type=refresh_token&refresh_token=#{TEST_REFRESH_TOKEN}"
      stub_request(:post, TOKEN_URL)
        .with(body: expected_body)
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!
    end

    def test_refresh_token_updates_access_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN"}.to_json)

      authenticator.refresh_token!

      assert_equal "NEW_ACCESS_TOKEN", authenticator.access_token
    end

    def test_refresh_token_updates_refresh_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "new", refresh_token: "NEW_REFRESH"}.to_json)

      authenticator.refresh_token!

      assert_equal "NEW_REFRESH", authenticator.refresh_token
    end

    def test_refresh_token_returns_response_body
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      result = authenticator.refresh_token!

      assert_equal "new", result["access_token"]
    end

    def test_refresh_token_updates_expires_at
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "new", expires_in: 7200}.to_json)

      before_refresh = Time.now
      authenticator.refresh_token!

      assert_operator authenticator.expires_at, :>=, before_refresh + 7200
    end

    def test_refresh_token_keeps_old_refresh_token_when_not_returned
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!

      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end
  end

  class OAuth2AuthenticatorRefreshTokenErrorTest < Minitest::Test
    cover OAuth2Authenticator

    def test_refresh_token_raises_on_error_with_description
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 400, body: {error: "invalid_grant", error_description: "Token expired"}.to_json)

      error = assert_raises(Error) { authenticator.refresh_token! }
      assert_equal "Token expired", error.message
    end

    def test_refresh_token_raises_on_error_without_description
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 400, body: {error: "invalid_grant"}.to_json)

      error = assert_raises(Error) { authenticator.refresh_token! }
      assert_equal "invalid_grant", error.message
    end

    def test_refresh_token_raises_on_error_with_default_message
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 500, body: {}.to_json)

      error = assert_raises(Error) { authenticator.refresh_token! }
      assert_equal "Token refresh failed", error.message
    end

    def test_refresh_token_raises_on_invalid_json_response
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 500, body: "Internal Server Error")

      error = assert_raises(Error) { authenticator.refresh_token! }
      assert_equal "Token refresh failed", error.message
    end
  end
end
