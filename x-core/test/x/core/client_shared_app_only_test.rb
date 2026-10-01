# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A copy of a client that authenticates as the app with an API key and secret shares the authenticator of the
  # client, and so the bearer token it fetched, unless the copy is given credentials of its own
  class ClientSharedAppOnlyTest < Minitest::Test
    cover_client
    cover AppOnlyAuthenticator

    USERS_URL = "https://api.x.com/2/users/1"

    def setup
      @token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      stub_request(:get, USERS_URL).to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})
      @client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
    end

    def test_a_copy_sends_the_bearer_token_the_client_fetched
      @client.get("users/1")
      copy = @client.with(read_timeout: 5)
      copy.get("users/1")

      assert_same @client.authenticator, copy.authenticator
      assert_requested @token_request, times: 1
    end

    def test_a_copy_given_the_api_key_and_secret_the_client_holds_shares_its_authenticator
      assert_same @client.authenticator, @client.with(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET).authenticator
    end

    def test_a_copy_given_credentials_of_its_own_fetches_a_token_of_its_own
      [{api_key: "OTHER_KEY"}, {api_key_secret: "OTHER_SECRET"}, {bearer_token: "OTHER_TOKEN"}].each do |options|
        refute_same @client.authenticator, @client.with(**options).authenticator, options.inspect
      end
    end

    def test_a_copy_at_another_path_of_the_origin_shares_the_authenticator
      assert_same @client.authenticator, @client.with(base_url: "https://api.x.com/1.1/").authenticator
    end

    def test_a_copy_at_another_origin_fetches_a_token_of_its_own_there
      @client.get("users/1")
      staging_token = stub_request(:post, "https://staging.example/oauth2/token")
        .to_return(status: 200, body: {token_type: "bearer", access_token: "STAGING_TOKEN"}.to_json)
      stub_request(:get, "https://staging.example/2/users/1").to_return(status: 200, body: "{}")
      copy = @client.with(base_url: "https://staging.example/2/")
      copy.get("users/1")

      refute_same @client.authenticator, copy.authenticator
      assert_requested staging_token, times: 1
      assert_requested :get, "https://staging.example/2/users/1", headers: {"Authorization" => "Bearer STAGING_TOKEN"}
    end

    def test_a_copy_that_signs_as_a_user_does_not_share_it
      copy = @client.with(access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)

      assert_instance_of OAuth1Authenticator, copy.authenticator
    end

    def test_a_copy_of_a_client_that_signs_as_a_user_does_not_take_an_app_only_authenticator
      client = Client.new(**test_oauth_credentials)

      assert_instance_of OAuth1Authenticator, client.with(read_timeout: 5).authenticator
    end
  end
end
