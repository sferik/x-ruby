# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class StreamTokenRejectionTest < Minitest::Test
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: "FETCHED"}.to_json)
    end

    def app_only_client(**options) = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, **options)

    def stream(client)
      objects = []
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| objects << object } }
      objects
    end

    def test_a_rejected_token_is_fetched_again_and_the_stream_opened_again
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer STALE"}).to_return(status: 401)
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer FETCHED"}).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")

      assert_equal [{"data" => {"id" => "1"}}], stream(app_only_client(bearer_token: "STALE"))
      assert_requested @token_request, times: 1
    end

    def test_a_user_client_streams_with_the_token_fetched_in_place_of_the_rejected_one
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer STALE"}).to_return(status: 401)
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer FETCHED"}).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(**test_oauth_credentials, bearer_token: "STALE")

      assert_equal [{"data" => {"id" => "1"}}], stream(client)
    end

    def test_a_token_fetched_in_place_of_a_rejected_one_that_is_rejected_raises
      stub_request(:get, STREAM_URL).to_return(status: 401)

      assert_raises(Unauthorized) { stream(app_only_client(bearer_token: "STALE")) }
      assert_requested @token_request, times: 1
      assert_requested :get, STREAM_URL, times: 2
    end

    def test_a_bearer_token_given_alone_is_not_fetched_again
      stub_request(:get, STREAM_URL).to_return(status: 401)

      assert_raises(Unauthorized) { stream(Client.new(bearer_token: "STALE")) }
      assert_not_requested @token_request
      assert_requested :get, STREAM_URL, times: 1
    end
  end
end
