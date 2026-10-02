# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client pointed at another host than X requests the token endpoints there, as it sends its requests
  class TokenEndpointOriginTest < Minitest::Test
    cover Core.const_get(:TokenEndpoint)
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator

    TEST_SERVER = "http://localhost:3000/2/"

    def test_the_url_of_a_token_endpoint_is_at_the_origin_of_the_base_url
      assert_equal "http://localhost:3000/oauth2/token", Core.const_get(:TokenEndpoint).url_at(TEST_SERVER, APP_ONLY_TOKEN_URL)
      assert_equal "http://localhost:3000/2/oauth2/token", Core.const_get(:TokenEndpoint).url_at(TEST_SERVER, OAUTH2_TOKEN_URL)
      assert_equal APP_ONLY_TOKEN_URL, Core.const_get(:TokenEndpoint).url_at(Client::DEFAULT_BASE_URL, APP_ONLY_TOKEN_URL)
    end

    def test_the_url_of_a_token_endpoint_is_under_the_path_the_base_url_serves_the_api_at
      url_at = Core.const_get(:TokenEndpoint).method(:url_at)

      assert_equal "https://gateway.example/x/oauth2/token", url_at.call("https://gateway.example/x/2/", APP_ONLY_TOKEN_URL)
      assert_equal "https://gateway.example/x/2/oauth2/token", url_at.call("https://gateway.example/x/2/", OAUTH2_TOKEN_URL)
      assert_equal "https://gateway.example/x/api/oauth2/token", url_at.call("https://gateway.example/x/api/1.1/", APP_ONLY_TOKEN_URL)
    end

    def test_a_base_url_whose_path_ends_in_no_version_of_the_api_serves_the_api_at_its_whole_path
      url_at = Core.const_get(:TokenEndpoint).method(:url_at)

      assert_equal "https://gateway.example/x/oauth2/token", url_at.call("https://gateway.example/x/", APP_ONLY_TOKEN_URL)
      assert_equal "https://gateway.example/v2x/oauth2/token", url_at.call("https://gateway.example/v2x/", APP_ONLY_TOKEN_URL)
      assert_equal "https://api.x.com/oauth2/token", url_at.call("https://api.x.com/1.1", APP_ONLY_TOKEN_URL)
    end

    def test_a_client_of_a_gateway_fetches_and_refreshes_its_tokens_under_the_path_of_the_gateway
      app_token = stub_request(:post, "https://gateway.example/x/oauth2/token").to_return(headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      refresh = stub_request(:post, "https://gateway.example/x/2/oauth2/token").to_return(headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: "new", refresh_token: "next", expires_in: 7200}.to_json)
      stub_request(:get, "https://gateway.example/x/2/users/me").to_return(headers: {"Content-Type" => "application/json"}, body: "{}")
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, base_url: "https://gateway.example/x/2/").get("users/me")
      Client.new(client_id: "id", access_token: "old", refresh_token: "refresh", base_url: "https://gateway.example/x/2/").authenticator.refresh!

      assert_requested app_token
      assert_requested refresh
    end

    def test_an_app_only_client_fetches_its_bearer_token_at_the_origin_of_its_base_url
      token_request = stub_request(:post, "http://localhost:3000/oauth2/token").to_return(headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      stub_request(:get, "#{TEST_SERVER}users/me").to_return(headers: {"Content-Type" => "application/json"}, body: "{}")
      Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, base_url: TEST_SERVER).get("users/me")

      assert_requested token_request
      assert_not_requested :post, APP_ONLY_TOKEN_URL
    end

    def test_an_oauth2_client_refreshes_its_token_at_the_origin_of_its_base_url
      refresh = stub_request(:post, "http://localhost:3000/2/oauth2/token").to_return(headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: "new", refresh_token: "next", expires_in: 7200}.to_json)
      client = Client.new(client_id: "id", access_token: "old", refresh_token: "refresh", base_url: TEST_SERVER)
      client.authenticator.refresh!

      assert_requested refresh
      assert_not_requested :post, OAUTH2_TOKEN_URL
    end

    def test_an_authenticator_requests_its_token_endpoint_at_the_origin_of_the_first_client_that_takes_it
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      authenticator.__send__(:token_requests_over, Core.const_get(:Connection).new, TEST_SERVER)
      authenticator.__send__(:token_requests_over, Core.const_get(:Connection).new, Client::DEFAULT_BASE_URL)

      assert_equal "http://localhost:3000/oauth2/token", authenticator.__send__(:token_request).url
    end
  end
end
