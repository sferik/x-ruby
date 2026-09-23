# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientTokenRefreshOriginTest < Minitest::Test
    cover_client

    USERS_ME = "https://api.x.com/2/users/me"

    def setup
      @refresh = stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_a_rejection_by_another_origin_refreshes_nothing
      stub_request(:get, "https://other.example.com/users/me").to_return(status: 401)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(Unauthorized) { client.get("https://other.example.com/users/me") }
      assert_not_requested @refresh
      assert_equal TEST_ACCESS_TOKEN, client.authenticator.access_token
    end

    def test_a_rejection_after_a_redirect_to_another_origin_refreshes_nothing
      stub_request(:get, USERS_ME).to_return(status: 302, headers: {"Location" => "https://other.example.com/users/me"})
      stub_request(:get, "https://other.example.com/users/me").to_return(status: 401)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(Unauthorized) { client.get("users/me") }
      assert_not_requested @refresh
      assert_requested :get, USERS_ME, times: 1
    end
  end
end
