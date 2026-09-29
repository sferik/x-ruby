# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A refresh whose tokens on_token_refresh raised for raises TokenReportFailed, which holds them, since the refresh
  # token they replaced is spent
  class TokenRefreshReportFailedTest < Minitest::Test
    cover_client
    cover OAuth2Authenticator
    cover Core::OAuth2Refresh
    cover Core::RefreshReporter

    USERS_ME = "https://api.x.com/2/users/me"

    # An error whose message is what a store that is down may raise
    class StorageDown < StandardError; end

    def setup
      @refresh = stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
      @failing = ->(_) { raise StorageDown, "connection refused" }
    end

    def test_a_refresh_raises_with_the_tokens_and_the_error_of_the_hook_as_its_cause
      authenticator = oauth2_authenticator_reporting_to(@failing)
      error = assert_raises(TokenReportFailed) { authenticator.refresh! }

      assert_equal %w[NEW_ACCESS_TOKEN NEW_REFRESH_TOKEN], [error.tokens.access_token, error.tokens.refresh_token]
      assert_instance_of StorageDown, error.cause
      assert_nil error.client
      assert_equal "The tokens were refreshed, but on_token_refresh raised for them: connection refused", error.message
    end

    def test_a_refresh_before_a_header_raises_with_the_tokens
      error = assert_raises(TokenReportFailed) { oauth2_authenticator_reporting_to(@failing, expires_at: Time.now - 1).header(nil) }

      assert_equal ["NEW_REFRESH_TOKEN", nil], [error.tokens.refresh_token, error.client]
    end

    def test_a_refresh_before_a_request_raises_with_the_client_and_the_tokens
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, on_token_refresh: @failing)
      error = assert_raises(TokenReportFailed) { client.get("users/me") }

      assert_same client, error.client
      assert_equal "NEW_REFRESH_TOKEN", error.tokens.refresh_token
      assert_instance_of StorageDown, error.cause
    end

    def test_a_refresh_of_a_rejected_token_raises_with_the_client_and_the_tokens
      stub_request(:get, USERS_ME).to_return(status: 401)
      client = Client.new(**test_oauth2_credentials, on_token_refresh: @failing)
      error = assert_raises(TokenReportFailed) { client.get("users/me") }

      assert_same client, error.client
      assert_equal "NEW_REFRESH_TOKEN", error.tokens.refresh_token
      assert_instance_of StorageDown, error.cause
      assert_requested :get, USERS_ME, times: 1
    end

    def test_the_client_holds_the_tokens_the_error_does
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, on_token_refresh: @failing)
      error = assert_raises(TokenReportFailed) { client.get("users/me") }

      assert_equal error.tokens.access_token, client.authenticator.send(:access_token)
    end
  end
end
