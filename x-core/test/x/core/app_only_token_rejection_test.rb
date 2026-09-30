# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AppOnlyTokenRejectionTest < Minitest::Test
    cover_client
    cover AppOnlyAuthenticator
    cover Core.const_get(:Origin)

    POST_URL = "https://api.x.com/2/tweets/1"

    def setup
      @token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return({status: 200, body: {access_token: "FIRST"}.to_json}, {status: 200, body: {access_token: "SECOND"}.to_json})
    end

    def test_a_rejected_token_is_fetched_again_and_the_request_sent_again
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer FIRST"})
        .to_return({status: 200, body: {data: {id: "1"}}.to_json}, {status: 401})
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer SECOND"}).to_return(status: 200, body: {data: {id: "2"}}.to_json)
      client = app_only_client
      client.get("tweets/1")

      assert_equal({"data" => {"id" => "2"}}, client.get("tweets/1"))
      assert_requested @token_request, times: 2
    end

    def test_a_given_token_that_is_rejected_is_replaced_with_one_fetched
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer GIVEN"}).to_return(status: 401)
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer FIRST"}).to_return(status: 200, body: "{}")

      assert_empty app_only_client(bearer_token: "GIVEN").get("tweets/1")
      assert_requested @token_request, times: 1
    end

    def test_a_token_fetched_for_the_request_is_not_fetched_again
      stub_request(:get, POST_URL).to_return(status: 401)

      assert_raises(Unauthorized) { app_only_client.get("tweets/1") }
      assert_requested @token_request, times: 1
      assert_requested :get, POST_URL, times: 1
    end

    def test_a_token_fetched_in_place_of_a_rejected_one_that_is_rejected_raises
      stub_request(:get, POST_URL).to_return(status: 401)

      assert_raises(Unauthorized) { app_only_client(bearer_token: "GIVEN").get("tweets/1") }
      assert_requested @token_request, times: 1
      assert_requested :get, POST_URL, times: 2
    end

    def test_a_rejection_by_another_origin_drops_nothing
      stub_request(:get, "https://other.example.com/tweets/1").to_return(status: 401)
      client = app_only_client(bearer_token: "GIVEN")

      assert_raises(Unauthorized) { client.get("https://other.example.com/tweets/1") }
      assert_not_requested @token_request
      assert_equal "GIVEN", client.authenticator.__send__(:bearer_token)
    end

    def test_a_rejection_that_names_no_uri_drops_nothing
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "GIVEN")
      error = Unauthorized.new(http_response: Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized"))

      assert_raises(Unauthorized) { authenticator.__send__(:retrying_rejected_token, URI("https://api.x.com/2/")) { raise error } }
      assert_equal "GIVEN", authenticator.__send__(:bearer_token)
    end

    def test_a_rejection_is_read_from_the_uri_of_the_response
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "GIVEN")
      http_response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      http_response.uri = URI(POST_URL)
      attempts = []
      authenticator.__send__(:retrying_rejected_token, URI("https://api.x.com/2/")) do
        attempts << authenticator.headers(nil)
        raise Unauthorized.new(http_response:) if attempts.one?
      end

      assert_equal ["Bearer GIVEN", "Bearer FIRST"], attempts.map { |header| header.fetch("Authorization") }
    end

    def test_the_rejection_of_a_token_is_private
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)

      %i[retrying_rejected_token drop_bearer_token].each { |name| refute_respond_to authenticator, name }
    end

    def test_a_token_another_request_already_replaced_is_kept
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "NEWER")
      authenticator.__send__(:drop_bearer_token, "OLDER")

      assert_equal "NEWER", authenticator.__send__(:bearer_token)
      assert_not_requested @token_request
    end

    def test_a_token_is_dropped_under_the_lock_a_fetch_holds
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "GIVEN")
      dropping = authenticator.instance_variable_get(:@mutex).synchronize do
        Thread.new { authenticator.__send__(:drop_bearer_token, "GIVEN") }.tap do |thread|
          Thread.pass until thread.status.eql?("sleep")

          assert_equal "GIVEN", authenticator.instance_variable_get(:@bearer_token)
        end
      end
      dropping.join

      assert_nil authenticator.instance_variable_get(:@bearer_token)
    end

    def test_the_app_only_copy_of_an_oauth1_client_fetches_a_rejected_token_again
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer FIRST"}).to_return(status: 401)
      stub_request(:get, POST_URL).with(headers: {"Authorization" => "Bearer SECOND"}).to_return(status: 200, body: "{}")

      assert_empty Client.new(**test_oauth_credentials).app_only.get("tweets/1")
      assert_requested @token_request, times: 2
    end

    private

    # A client that authenticates as the app with its API key and secret
    def app_only_client(**options) = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, **options)
  end
end
