# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  class StreamingClientReconnectTest < Minitest::Test
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      @sleeps = []
    end

    def test_a_stream_reconnects_after_a_rate_limit_however_the_client_retries_requests
      stub_request(:get, STREAM_URL)
        .to_return({status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => Time.now.to_i.to_s}},
          {body: "{\"data\":{\"id\":\"1\"}}\r\n"}, {status: 401, body: "{}", headers: {"Content-Type" => "application/json"}})
      streaming_client = @client.streaming(max_reconnects: 1)
      posts = []

      assert_raises(Unauthorized) { without_sleeping(streaming_client) { streaming_client.stream("tweets/sample/stream") { |post| posts << post } } }
      assert_equal [[{"data" => {"id" => "1"}}], [60, 0.0]], [posts, @sleeps]
      assert_requested(:get, STREAM_URL, times: 3)
    end

    def test_reads_with_a_short_timeout_of_its_own
      client = Client.new(read_timeout: 60)

      assert_equal [30, 5], [client.streaming.read_timeout, client.streaming(read_timeout: 5).read_timeout]
      assert_equal [Float::INFINITY, 3], [client.streaming.max_reconnects, client.streaming(max_reconnects: 3).max_reconnects]
      assert_equal 60, client.read_timeout
    end

    def test_connects_as_the_client_does_apart_from_the_read_timeout
      client = Client.new(open_timeout: 5, read_timeout: 60, write_timeout: 7, debug_output: $stderr, proxy_url: "https://proxy.example.com:8080")
      streaming_client = client.streaming

      assert_equal [5, 30, 7], [streaming_client.open_timeout, streaming_client.read_timeout, streaming_client.write_timeout]
      assert_equal [$stderr, "https://proxy.example.com:8080"], [streaming_client.debug_output, streaming_client.proxy_url]
    end

    def test_a_stream_that_drops_reconnects
      stub_request(:get, STREAM_URL)
        .to_return({body: "{\"data\":{\"id\":\"1\"}}\r\n"}, {status: 503}, {body: "{\"data\":{\"id\":\"2\"}}\r\n"}).then.to_raise(Errno::ECONNRESET)
      posts = []
      streaming_client = @client.streaming(max_reconnects: 2)

      assert_raises(NetworkError) { without_sleeping(streaming_client) { streaming_client.stream("tweets/sample/stream") { |post| posts << post.dig("data", "id") } } }
      assert_equal [%w[1 2], [0.0, 10, 0.0, 0.25], 2], [posts, @sleeps, streaming_client.max_reconnects]
    end

    def test_inspect_names_the_client_it_streams_with
      assert_equal "#<X::StreamingClient client=#{@client.inspect}>", @client.streaming.inspect
    end

    private

    # Stream without waiting for the backoff between reconnects, collecting what it would have waited
    def without_sleeping(streaming_client, &)
      streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(seconds) { @sleeps << seconds }, &)
    end
  end
end
