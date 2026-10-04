# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientAppOnlyCopyTest < Minitest::Test
    cover_client

    def setup
      @token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def test_an_oauth1_client_returns_the_same_copy
      client = Client.new(**test_oauth_credentials)
      copy = client.app_only

      assert_same copy, client.app_only
      assert_requested @token_request, times: 1
    end

    def test_threads_that_ask_for_the_copy_together_get_one_copy_and_fetch_one_token
      WebMock.reset!
      token_request = stub_request(:post, APP_ONLY_TOKEN_URL).to_return do
        sleep 0.05
        {status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json}
      end
      client = Client.new(**test_oauth_credentials)
      copies = Array.new(4) { Thread.new { client.app_only } }.map(&:value)

      assert_equal [copies.first] * 4, copies
      assert_requested token_request, times: 1
    end

    def test_copies_of_a_client_share_the_token_it_fetched
      client = Client.new(**test_oauth_credentials)
      copies = Array.new(3) { client.with(headers: {"X-Request" => "copy"}) }

      refute_same client.app_only, copies.first.app_only
      assert_equal [sent_token(client)] * 3, copies.map { |copy| sent_token(copy) }
      assert_requested @token_request, times: 1
    end

    def test_a_copy_shares_the_token_the_client_has_yet_to_fetch
      client = Client.new(**test_oauth_credentials)
      client.with.app_only
      client.app_only

      assert_requested @token_request, times: 1
    end

    def test_copies_made_together_on_threads_share_one_token
      client = Client.new(**test_oauth_credentials)
      build = AppOnlyAuthenticator.method(:new)
      slow_build = lambda do |**options|
        sleep 0.05
        build.call(**options)
      end
      copies = AppOnlyAuthenticator.stub(:new, slow_build) { Array.new(4) { Thread.new { client.with } }.map(&:value) }
      copies.each(&:app_only)

      assert_requested @token_request, times: 1
    end

    def test_a_copy_of_a_copy_shares_the_token
      client = Client.new(**test_oauth_credentials)
      client.app_only
      client.with.with.app_only

      assert_requested @token_request, times: 1
    end

    def test_a_copy_of_an_oauth2_client_shares_the_token
      client = Client.new(**test_oauth2_credentials, api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      client.app_only
      client.with(read_timeout: 5).app_only

      assert_requested @token_request, times: 1
    end

    def test_a_copy_with_other_credentials_of_the_app_fetches_a_token_of_its_own
      client = Client.new(**test_oauth_credentials)
      client.app_only
      client.with(api_key: "OTHER_KEY").app_only
      client.with(api_key_secret: "OTHER_SECRET").app_only

      assert_requested @token_request, times: 3
    end

    def test_a_copy_with_another_base_url_fetches_a_token_of_its_own
      other_token_request = stub_request(:post, "https://other.example/oauth2/token")
        .to_return(status: 200, body: {token_type: "bearer", access_token: "OTHER"}.to_json)
      client = Client.new(**test_oauth_credentials)
      client.app_only

      assert_equal "OTHER", sent_token(client.with(base_url: "https://other.example/2/"))
      assert_requested @token_request, times: 1
      assert_requested other_token_request, times: 1
    end

    def test_a_copy_given_a_bearer_token_sends_it
      client = Client.new(**test_oauth_credentials)

      assert_equal "OWN", sent_token(client.with(bearer_token: "OWN"))
      assert_not_requested @token_request
    end

    private

    # The bearer token the app-only copy of a client sends
    def sent_token(client) = client.app_only.authenticator.headers(nil).fetch("Authorization").delete_prefix("Bearer ")
  end
end
