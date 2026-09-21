# frozen_string_literal: true

require "base64"
require_relative "../../test_helper"

module X
  TOKEN_URL = OAuth2Authenticator::TOKEN_URL

  class OAuth2AuthenticatorInitializationTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

    def test_initialize_with_required_credentials
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_equal TEST_CLIENT_ID, authenticator.client_id
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end

    def test_same_credentials
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_operator authenticator, :same_credentials?, authenticator
      assert_operator authenticator, :same_credentials?, OAuth2Authenticator.new(**test_oauth2_credentials)
      refute_operator authenticator, :same_credentials?, OAuth2Authenticator.new(**test_oauth2_credentials, client_id: "OTHER")
    end

    def test_same_credentials_compares_every_credential
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      %i[client_id client_secret access_token refresh_token].each do |credential|
        other = OAuth2Authenticator.new(**test_oauth2_credentials, credential => "OTHER")

        refute_operator authenticator, :same_credentials?, other, "#{credential} is left out of the comparison"
        refute_operator other, :same_credentials?, authenticator
      end
    end

    def test_same_credentials_ignores_what_is_not_a_credential
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      other = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now + 3600, connection: Connection.new(open_timeout: 1))

      assert_operator authenticator, :same_credentials?, other
    end

    def test_a_public_client_has_the_credentials_of_a_public_client
      public_client = OAuth2Authenticator.new(**test_oauth2_credentials.except(:client_secret))

      assert_operator public_client, :same_credentials?, OAuth2Authenticator.new(**test_oauth2_credentials.except(:client_secret))
      refute_operator public_client, :same_credentials?, OAuth2Authenticator.new(**test_oauth2_credentials)
    end

    def test_no_other_authenticator_holds_the_same_credentials
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      [Authenticator.new, BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN), OAuth1Authenticator.new(**test_oauth_credentials), nil, "OTHER"].each do |other|
        refute_operator authenticator, :same_credentials?, other
      end
    end

    # A subclass of the authenticator signs with the credentials it holds, so a client that shares one with a client
    # built from a subclass shares a refresh token X accepts once, as any two clients of the same credentials do.
    def test_a_subclass_of_the_authenticator_holds_the_same_credentials
      subclass = Class.new(OAuth2Authenticator)

      assert_operator OAuth2Authenticator.new(**test_oauth2_credentials), :same_credentials?, subclass.new(**test_oauth2_credentials)
    end

    def test_the_credentials_compared_are_not_handed_out
      refute_respond_to OAuth2Authenticator.new(**test_oauth2_credentials), :credentials
    end

    def test_inspect_hides_the_secrets
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_equal "#<X::OAuth2Authenticator client_id=\"#{TEST_CLIENT_ID}\" expires_at=nil>", authenticator.inspect
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
    cover Core::TokenEndpoint

    def test_header_returns_bearer_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      header = authenticator.header(nil)

      assert_equal({"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}, header)
    end
  end

  class OAuth2AuthenticatorTokenExpirationTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

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
      expires_at = now + 30
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        assert_predicate authenticator, :token_expired?
      end
    end

    def test_token_expired_returns_true_within_buffer
      now = Time.now
      expires_at = now + 29
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        assert_predicate authenticator, :token_expired?
      end
    end

    def test_token_expired_returns_false_just_outside_buffer
      now = Time.now
      expires_at = now + 31
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: expires_at)

      Time.stub :now, now do
        refute_predicate authenticator, :token_expired?
      end
    end
  end

  class OAuth2AuthenticatorRefreshTokenTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

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

    def test_refresh_token_of_a_public_client_sends_its_client_id_without_basic_auth
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials.except(:client_secret))
      refresh = stub_request(:post, TOKEN_URL)
        .with(body: "grant_type=refresh_token&refresh_token=#{TEST_REFRESH_TOKEN}&client_id=#{TEST_CLIENT_ID}") { |request| !request.headers.key?("Authorization") }
        .to_return(status: 200, body: {access_token: "new"}.to_json)
      authenticator.refresh_token!

      assert_requested refresh
      assert_equal "new", authenticator.access_token
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

    def test_refresh_token_forgets_expires_at_when_no_lifetime_is_returned
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now + 3600)
      stub_request(:post, TOKEN_URL).to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!

      assert_nil authenticator.expires_at
    end

    def test_refresh_token_keeps_old_refresh_token_when_not_returned
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "new"}.to_json)

      authenticator.refresh_token!

      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end
  end

  class OAuth2AuthenticatorAutomaticRefreshTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

    def setup
      @refresh = stub_request(:post, TOKEN_URL)
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_header_refreshes_an_expired_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)

      assert_equal({"Authorization" => "Bearer NEW_ACCESS_TOKEN"}, authenticator.header(nil))
      assert_requested @refresh, times: 1
    end

    def test_header_refreshes_an_expired_token_once_when_no_lifetime_is_returned
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      2.times { authenticator.header(nil) }

      assert_requested @refresh, times: 1
    end

    def test_header_keeps_an_unexpired_token
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now + 3600)

      assert_equal({"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}, authenticator.header(nil))
      assert_not_requested @refresh
    end

    def test_on_refresh_receives_the_authenticator_after_its_tokens_change
      tokens = []
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, on_refresh: ->(auth) { tokens << [auth, auth.refresh_token] })
      authenticator.refresh_token!

      assert_equal [[authenticator, "NEW_REFRESH_TOKEN"]], tokens
    end

    def test_on_refresh_defaults_to_nil
      assert_nil OAuth2Authenticator.new(**test_oauth2_credentials).on_refresh
    end

    def test_refresh_rejected_token_refreshes_the_token_that_was_rejected
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert authenticator.refresh_rejected_token!(TEST_ACCESS_TOKEN)
      assert_equal "NEW_ACCESS_TOKEN", authenticator.access_token
      assert_requested @refresh, times: 1
    end

    def test_refresh_rejected_token_skips_a_token_already_replaced
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert authenticator.refresh_rejected_token!("OLDER_ACCESS_TOKEN")
      assert_not_requested @refresh
    end

    def test_refresh_rejected_token_reports_a_refresh_that_returned_the_same_token
      stub_request(:post, TOKEN_URL).to_return(status: 200, body: {access_token: TEST_ACCESS_TOKEN}.to_json)
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      refute authenticator.refresh_rejected_token!(TEST_ACCESS_TOKEN)
    end

    def unauthorized
      Unauthorized.new(http_response: Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized"))
    end

    def test_retrying_rejected_token_returns_what_the_request_returns
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_equal :ok, authenticator.retrying_rejected_token { :ok }
      assert_not_requested @refresh
    end

    def test_retrying_rejected_token_refreshes_and_runs_the_request_again
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      tokens = []
      result = authenticator.retrying_rejected_token do
        tokens << authenticator.access_token
        raise unauthorized if tokens.one?

        :ok
      end

      assert_equal [:ok, [TEST_ACCESS_TOKEN, "NEW_ACCESS_TOKEN"]], [result, tokens]
    end

    def test_retrying_rejected_token_refreshes_the_token_the_request_was_sent_with
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      attempts = 0
      result = authenticator.retrying_rejected_token do
        attempts += 1
        authenticator.instance_variable_set(:@access_token, "REPLACED") if attempts.eql?(1)
        raise unauthorized if attempts.eql?(1)

        :ok
      end

      assert_equal [:ok, 2, "REPLACED"], [result, attempts, authenticator.access_token]
      assert_not_requested @refresh
    end

    def test_retrying_rejected_token_raises_a_second_rejection
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      attempts = 0

      assert_raises(Unauthorized) do
        authenticator.retrying_rejected_token do
          attempts += 1
          raise unauthorized
        end
      end
      assert_equal 2, attempts
    end

    def test_retrying_rejected_token_raises_when_a_refresh_keeps_the_token
      stub_request(:post, TOKEN_URL).to_return(status: 200, body: {access_token: TEST_ACCESS_TOKEN}.to_json)
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      attempts = 0

      assert_raises(Unauthorized) do
        authenticator.retrying_rejected_token do
          attempts += 1
          raise unauthorized
        end
      end
      assert_equal 1, attempts
    end
  end

  class OAuth2AuthenticatorConcurrentRefreshTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

    # Answer the token endpoint slowly, so that concurrent callers overlap the refresh
    def stub_slow_refresh
      stub_request(:post, TOKEN_URL).to_return do
        sleep 0.05
        {status: 200, body: {access_token: "NEW_ACCESS_TOKEN", expires_in: 7200}.to_json}
      end
    end

    # Run a block in several threads at once, each after the first has begun
    def concurrently(count = 4, &block)
      first = Thread.new(&block)
      sleep 0.01
      [first, *Array.new(count - 1) { Thread.new(&block) }].each(&:join)
    end

    def test_concurrent_refreshes_of_a_rejected_token_refresh_once
      stub_slow_refresh
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      concurrently { authenticator.refresh_rejected_token!(TEST_ACCESS_TOKEN) }

      assert_requested :post, TOKEN_URL, times: 1
    end

    def test_concurrent_headers_refresh_an_expired_token_once
      stub_slow_refresh
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      concurrently { authenticator.header(nil) }

      assert_requested :post, TOKEN_URL, times: 1
    end

    def test_a_header_waits_for_a_refresh_in_progress
      stub_slow_refresh
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      refreshing = Thread.new { authenticator.refresh_token! }
      sleep 0.01

      assert_equal({"Authorization" => "Bearer NEW_ACCESS_TOKEN"}, authenticator.header(nil))
      refreshing.join

      assert_requested :post, TOKEN_URL, times: 1
    end
  end

  class OAuth2AuthenticatorRefreshTokenErrorTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core::TokenEndpoint

    def test_refresh_token_raises_on_error_with_description
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 400, body: {error: "invalid_grant", error_description: "Token expired"}.to_json)

      error = assert_raises(AuthorizationError) { authenticator.refresh_token! }
      assert_equal ["Token expired", "invalid_grant", 400], [error.message, error.error_code, error.status]
    end

    def test_refresh_token_raises_on_error_without_description
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 400, body: {error: "invalid_grant"}.to_json)

      error = assert_raises(AuthorizationError) { authenticator.refresh_token! }
      assert_equal "invalid_grant", error.message
    end

    def test_refresh_token_raises_on_error_with_default_message
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 500, body: {}.to_json)

      error = assert_raises(AuthorizationError) { authenticator.refresh_token! }
      assert_equal ["Token refresh failed", nil, 500], [error.message, error.error_code, error.status]
    end

    def test_refresh_token_raises_on_invalid_json_response
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      stub_request(:post, TOKEN_URL)
        .to_return(status: 500, body: "Internal Server Error")

      error = assert_raises(AuthorizationError) { authenticator.refresh_token! }
      assert_equal "Token refresh failed", error.message
    end
  end
end
