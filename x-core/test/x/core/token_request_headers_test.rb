# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A token request is sent with the User-Agent of the gem and the headers of the client that sends it, beneath the
  # headers of the token request itself
  class TokenRequestHeadersTest < Minitest::Test
    cover Core.const_get(:TokenEndpoint)
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover_client

    USER_AGENT = Core.const_get(:RequestBuilder)::DEFAULT_HEADERS.fetch("User-Agent")
    GATEWAY = {"X-Gateway-Key" => "g"}.freeze
    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze
    REFRESHED = {token_type: "bearer", access_token: "new", refresh_token: "next", expires_in: 7200}.to_json

    def setup
      stub_request(:get, "https://api.x.com/2/users/me").to_return(headers: JSON_HEADERS, body: "{}")
    end

    def stub_bearer_token(**headers)
      stub_request(:post, APP_ONLY_TOKEN_URL).with(headers:)
        .to_return(headers: JSON_HEADERS, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def stub_refresh(**options)
      stub_request(:post, OAUTH2_TOKEN_URL).with(**options).to_return(headers: JSON_HEADERS, body: REFRESHED)
    end

    def test_the_bearer_token_is_fetched_with_the_user_agent_of_the_gem
      token = stub_bearer_token("User-Agent" => USER_AGENT)
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET).get("users/me")

      assert_requested token
    end

    def test_the_bearer_token_is_fetched_with_the_headers_of_the_client
      token = stub_bearer_token(**GATEWAY, "User-Agent" => USER_AGENT)
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, headers: GATEWAY).get("users/me")

      assert_requested token
      assert_requested :get, "https://api.x.com/2/users/me", headers: GATEWAY
    end

    def test_a_user_agent_of_the_client_replaces_the_one_of_the_gem_in_a_token_request
      token = stub_bearer_token("User-Agent" => "my-app/1.0")
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, headers: {"user-agent" => "my-app/1.0"}).get("users/me")

      assert_requested token
    end

    def test_the_headers_of_the_token_request_replace_those_of_the_client
      basic = "Basic #{["#{TEST_API_KEY}:#{TEST_API_KEY_SECRET}"].pack("m0")}"
      token = stub_bearer_token("Authorization" => basic, "Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json")
      headers = {"authorization" => "Bearer other", "content-type" => "text/plain", "Accept" => "text/html"}
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, headers:).get("users/me")

      assert_requested token
    end

    def test_the_authorization_header_of_the_client_is_not_sent_with_a_token_request_that_carries_none
      refresh = stub_refresh(headers: GATEWAY)
      Client.new(client_id: TEST_CLIENT_ID, access_token: "old", refresh_token: "refresh", headers: {"authorization" => "Bearer other", **GATEWAY})
        .authenticator.refresh!

      assert_requested refresh
      assert_requested(:post, OAUTH2_TOKEN_URL) { |request| !request.headers.key?("Authorization") }
    end

    def test_a_refresh_is_sent_with_the_headers_of_the_client_that_took_the_authenticator_first
      refresh = stub_refresh(headers: {**GATEWAY, "User-Agent" => USER_AGENT})
      client = Client.new(**test_oauth2_credentials, headers: GATEWAY)
      client.with(headers: {"X-Other" => "o"}).authenticator.refresh!

      assert_requested refresh
    end

    def test_a_token_request_of_an_authenticator_no_client_took_is_sent_with_the_user_agent_of_the_gem
      token = stub_bearer_token("User-Agent" => USER_AGENT)
      refresh = stub_refresh(headers: {"User-Agent" => USER_AGENT})
      AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET).headers(nil)
      OAuth2Authenticator.new(**test_oauth2_credentials).refresh!

      assert_requested token
      assert_requested refresh
    end

    def test_a_refresh_before_a_request_is_sent_with_the_headers_of_the_client_that_sends_it
      refresh = stub_refresh(headers: {"X-Other" => "o", "User-Agent" => USER_AGENT})
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, headers: GATEWAY)
      client.with(headers: {"X-Other" => "o"}).get("users/me")

      assert_requested refresh
      assert_not_requested :post, OAUTH2_TOKEN_URL, headers: GATEWAY
    end

    def test_a_refresh_of_a_rejected_token_is_sent_with_the_headers_of_the_client_that_sends_it
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"})
        .to_return(status: 401, headers: JSON_HEADERS, body: "{}")
      refresh = stub_refresh(headers: {"X-Other" => "o"})
      Client.new(**test_oauth2_credentials, headers: GATEWAY).with(headers: {"X-Other" => "o"}).get("users/me")

      assert_requested refresh
    end
  end
end
