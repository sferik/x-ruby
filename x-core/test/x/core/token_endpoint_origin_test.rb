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
