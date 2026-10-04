# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A copy that shares the OAuth 2.0 authenticator of its client but is pointed at another origin refreshes at the
  # token endpoint of that origin, which its requests go to, rather than at the one of the client
  class ClientWithRefreshOriginTest < Minitest::Test
    cover_client
    cover Core.const_get(:OAuth2Refresh)
    cover OAuth2Authenticator

    TOKENS = {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.freeze

    def setup
      @refreshes = %w[https://api.x.com/2/oauth2/token http://localhost:4000/2/oauth2/token].to_h do |url|
        [url, stub_request(:post, url).to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: TOKENS.to_json)]
      end
    end

    def test_a_copy_pointed_at_another_origin_refreshes_there
      copy = expired_client.with(base_url: "http://localhost:4000/2/")
      stub_request(:get, "http://localhost:4000/2/users/me").to_return(status: 200, body: "{}")
      copy.get("users/me")

      assert_requested @refreshes.fetch("http://localhost:4000/2/oauth2/token")
      assert_not_requested @refreshes.fetch("https://api.x.com/2/oauth2/token")
    end

    def test_the_client_a_copy_was_made_from_refreshes_at_its_own_origin
      client = expired_client
      client.with(base_url: "http://localhost:4000/2/")
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
      client.get("users/me")

      assert_requested @refreshes.fetch("https://api.x.com/2/oauth2/token")
      assert_not_requested @refreshes.fetch("http://localhost:4000/2/oauth2/token")
    end

    def test_a_refresh_for_no_client_goes_to_the_origin_of_the_client_that_took_the_authenticator_first
      client = expired_client
      client.with(base_url: "http://localhost:4000/2/").authenticator.refresh!

      assert_requested @refreshes.fetch("https://api.x.com/2/oauth2/token")
    end

    private

    def expired_client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 5)
  end
end
