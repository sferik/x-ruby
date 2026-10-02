# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error the on_response of a client raises for a failed response of a stream stops the stream, and reaches the
  # caller as it was raised, even one a stream reconnects after, which X::Client#get_stream raises as it was
  class StreamingClientFailedResponseHookTest < Minitest::Test
    cover Streaming.const_get(:CallbackError)
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      stub_request(:get, STREAM_URL).to_return(status: 503)
    end

    def test_an_on_response_hook_that_raises_for_a_failed_response_stops_the_stream
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { raise Errno::ECONNREFUSED })

      assert_raises(Errno::ECONNREFUSED) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_error_of_the_api_an_on_response_hook_raises_for_a_failed_response_stops_the_stream
      unavailable = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { raise unavailable }).streaming(max_reconnects: 3)
      error = without_sleeping(streaming_client) do
        assert_raises(ServiceUnavailable) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      end

      assert_same unavailable, error
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_a_network_error_an_on_response_hook_raises_for_a_failed_response_stops_the_stream
      dropped = NetworkError.new("the hook could not connect")
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { raise dropped }).streaming(max_reconnects: 3)
      error = without_sleeping(streaming_client) do
        assert_raises(NetworkError) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      end

      assert_same dropped, error
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_on_response_hook_that_returns_lets_a_failed_response_reconnect
      calls = []
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(response) { calls << response.status }).streaming(max_reconnects: 1)

      without_sleeping(streaming_client) do
        assert_raises(ServiceUnavailable) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      end

      assert_equal [503, 503], calls
      assert_requested(:get, STREAM_URL, times: 2)
    end

    private

    def without_sleeping(streaming_client, &)
      streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(_seconds) {}, &)
    end
  end
end
