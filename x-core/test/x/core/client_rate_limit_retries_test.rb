require_relative "../../test_helper"

module X
  class ClientRateLimitRetriesTest < Minitest::Test
    cover Client

    URL = "https://api.twitter.com/2/users/me".freeze
    SUCCESS = {status: 200, body: '{"data":{"id":"1"}}', headers: {"Content-Type" => "application/json"}}.freeze

    def setup
      @sleeps = []
      @responses = []
    end

    def test_options_default_to_no_retries_and_a_15_minute_wait
      client = Client.new

      assert_equal [0, 900, Float::INFINITY], [client.max_rate_limit_retries, client.max_rate_limit_wait, client.max_stream_reconnects]
    end

    def test_options_can_be_set_and_are_copied
      client = Client.new(max_rate_limit_retries: 3, max_rate_limit_wait: 60)

      assert_equal [3, 60], [client.max_rate_limit_retries, client.max_rate_limit_wait]
      client.max_rate_limit_retries = 1
      client.max_rate_limit_wait = 10

      assert_equal [1, 10], [client.copy.max_rate_limit_retries, client.copy.max_rate_limit_wait]
    end

    def test_a_request_is_signed_afresh_and_retried_after_the_reset
      client = retrying_client(**test_oauth_credentials)
      nonces = []
      stub_request(:get, URL).with { |request| nonces << nonce_of(request) }.to_return(refused, SUCCESS)

      assert_equal({"data" => {"id" => "1"}}, without_sleeping(client) { client.get("users/me") })
      assert_equal [[429, 200], [0], 2], [@responses, @sleeps, nonces.uniq.size]
    end

    def test_a_request_without_retries_raises_at_once
      client = Client.new
      stub_request(:post, "https://api.twitter.com/2/tweets").to_return(refused)

      assert_raises(TooManyRequests) { without_sleeping(client) { client.post("tweets", {text: "hi"}) } }
      assert_requested(:post, "https://api.twitter.com/2/tweets", times: 1)
      assert_empty @sleeps
    end

    def test_a_stream_is_retried_after_the_reset
      client = retrying_client
      stub_request(:get, "https://api.twitter.com/2/tweets/sample/stream").to_return(refused, {status: 200, body: "{\"data\":{\"id\":\"1\"}}\r\n"})
      posts = []
      without_sleeping(client) { client.stream("tweets/sample/stream") { |post| posts << post } }

      assert_equal [[{"data" => {"id" => "1"}}], [0]], [posts, @sleeps]
      assert_requested(:get, "https://api.twitter.com/2/tweets/sample/stream", times: 2)
    end

    private

    def retrying_client(**credentials)
      Client.new(**credentials, max_rate_limit_retries: 1, max_stream_reconnects: 0, on_response: ->(response) { @responses << response.status })
    end

    def nonce_of(request)
      request.headers["Authorization"][/oauth_nonce="([^"]+)"/, 1]
    end

    def refused
      {status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => Time.now.to_i.to_s}}
    end

    def without_sleeping(client, &)
      client.instance_variable_get(:@rate_limit_handler).stub(:sleep, ->(seconds) { @sleeps << seconds }, &)
    end
  end
end
