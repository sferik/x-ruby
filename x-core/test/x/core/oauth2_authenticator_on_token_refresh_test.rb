# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class OAuth2AuthenticatorOnTokenRefreshTest < Minitest::Test
    cover OAuth2Authenticator

    def setup
      @refresh = stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
      @refreshed = []
    end

    def authenticator(**options)
      OAuth2Authenticator.new(**test_oauth2_credentials, on_token_refresh: ->(auth) { @refreshed << auth.access_token }, **options)
    end

    def test_refresh_returns_the_authenticator_after_on_token_refresh
      assert_equal ["NEW_REFRESH_TOKEN", ["NEW_ACCESS_TOKEN"]], [authenticator.refresh!.refresh_token, @refreshed]
    end

    def test_header_passes_a_refresh_to_on_token_refresh
      authenticator(expires_at: Time.now - 1).header(nil)

      assert_equal ["NEW_ACCESS_TOKEN"], @refreshed
    end

    def test_header_without_a_refresh_leaves_on_token_refresh_alone
      authenticator(expires_at: Time.now + 3600).header(nil)

      assert_empty @refreshed
    end

    def test_refresh_rejected_token_passes_a_refresh_to_on_token_refresh
      assert authenticator.send(:refresh_rejected_token!, TEST_ACCESS_TOKEN)
      assert_equal ["NEW_ACCESS_TOKEN"], @refreshed
    end

    def test_refresh_rejected_token_without_a_refresh_leaves_on_token_refresh_alone
      assert authenticator.send(:refresh_rejected_token!, "OLDER_ACCESS_TOKEN")
      assert_empty @refreshed
    end

    def test_on_token_refresh_can_ask_the_authenticator_for_a_header
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", expires_in: 7200}.to_json)
      headers = []
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1,
        on_token_refresh: ->(auth) { headers << auth.header(nil) })

      assert_equal({"Authorization" => "Bearer NEW_ACCESS_TOKEN"}, authenticator.header(nil))
      assert_equal [{"Authorization" => "Bearer NEW_ACCESS_TOKEN"}], headers
    end

    def test_on_token_refresh_can_refresh_a_rejected_token
      replaced = []
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials,
        on_token_refresh: ->(auth) { replaced << auth.send(:refresh_rejected_token!, TEST_ACCESS_TOKEN) })

      assert authenticator.send(:refresh_rejected_token!, TEST_ACCESS_TOKEN)
      assert_equal [true], replaced
      assert_requested @refresh, times: 1
    end
  end

  class ClientOnTokenRefreshTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", expires_in: 7200}.to_json)
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer NEW_ACCESS_TOKEN"})
        .to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: '{"data":{"id":"1"}}')
    end

    def test_on_token_refresh_can_send_a_request_with_the_client
      users = []
      client = nil #: Client?
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, on_token_refresh: ->(_) { users << client&.get("users/me") })

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_equal [{"data" => {"id" => "1"}}], users
    end
  end
end
