# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # X issues no refresh token for an authorization without offline.access, and the access token it issues acts for
  # the user all the same: a client built of it authenticates with OAuth 2.0 as that user, cannot refresh, and cannot
  # authenticate as the app
  class OAuth2WithoutRefreshTokenTest < Minitest::Test
    cover_client
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover OAuth2Authorization
    cover StreamingClient

    TOKEN_URL = "https://api.x.com/2/oauth2/token"
    CREDENTIALS = {client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN}.freeze

    def test_a_client_authenticates_as_the_user_with_the_access_token
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"})
      client = Client.new(**CREDENTIALS)
      client.get("users/me")

      assert_instance_of OAuth2Authenticator, client.authenticator
      assert_requested :get, "https://api.x.com/2/users/me"
    end

    def test_a_client_cannot_authenticate_as_the_app
      assert_raises(UnsupportedOperation) { Client.new(**CREDENTIALS).app_only }
    end

    def test_a_stream_raises_before_it_sends_the_token_of_the_user
      error = assert_raises(UnsupportedOperation) { Client.new(**CREDENTIALS).streaming.stream("tweets/search/stream") { flunk "unexpected yield" } }

      assert_match(/OAuth 2.0 as a user/, error.message)
      assert_not_requested :get, "https://api.x.com/2/tweets/search/stream"
    end

    def test_an_expired_token_is_sent_as_it_is_rather_than_refreshed
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"})
      Client.new(**CREDENTIALS, expires_at: Time.now - 60).get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me"
      assert_not_requested :post, TOKEN_URL
    end

    def test_a_rejected_token_raises_unauthorized_without_a_refresh
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 401, headers: {"Content-Type" => "application/json"},
        body: '{"title":"Unauthorized","detail":"Unauthorized"}')

      assert_raises(Unauthorized) { Client.new(**CREDENTIALS).get("users/me") }
      assert_requested :get, "https://api.x.com/2/users/me", times: 1
      assert_not_requested :post, TOKEN_URL
    end

    def test_refresh_raises_unsupported_operation_before_any_request
      error = assert_raises(UnsupportedOperation) { OAuth2Authenticator.new(**CREDENTIALS).refresh! }

      assert_match(/holds no refresh token/, error.message)
      assert_not_requested :post, TOKEN_URL
    end

    def test_a_copy_shares_the_authenticator
      client = Client.new(**CREDENTIALS, client_secret: TEST_CLIENT_SECRET)

      assert_same client.authenticator, client.with(max_retries: 0).authenticator
    end

    def test_inspect_reveals_no_token
      client = Client.new(**CREDENTIALS)

      refute_includes client.inspect, TEST_ACCESS_TOKEN
      assert_equal %(#<X::OAuth2Authenticator client_id="#{TEST_CLIENT_ID}" expires_at=nil>), client.authenticator.inspect
    end

    def test_the_client_of_an_authorization_without_offline_access_cannot_authenticate_as_the_app
      stub_request(:post, TOKEN_URL).to_return(body: {token_type: "bearer", access_token: "ACCESS", expires_in: 7200}.to_json)
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/callback", state: "STATE")
      client = authorization.client("state=STATE&code=CODE")

      assert_raises(UnsupportedOperation) { client.app_only }
    end
  end
end
