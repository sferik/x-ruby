# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientAppOnlyCopyTest < Minitest::Test
    cover_client

    def setup
      @token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def test_an_oauth1_client_returns_the_same_copy_until_its_settings_change
      client = Client.new(**test_oauth_credentials)
      copy = client.app_only

      assert_same copy, client.app_only
      client.read_timeout = 5

      refute_same copy, client.app_only
      assert_equal 5, client.app_only.read_timeout
    end

    def test_threads_that_ask_for_the_copy_together_get_one_copy_and_fetch_one_token
      WebMock.reset!
      token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return do
        sleep 0.05
        {status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json}
      end
      client = Client.new(**test_oauth_credentials)
      copies = Array.new(4) { Thread.new { client.app_only } }.map(&:value)

      assert_equal [copies.first] * 4, copies
      assert_requested token_request, times: 1
    end

    def test_changing_credentials_fetches_the_token_again
      client = Client.new(**test_oauth_credentials)
      copy = client.app_only
      client.api_key = "NEW_API_KEY"

      refute_same copy, client.app_only
      assert_requested @token_request, times: 2
    end
  end
end
