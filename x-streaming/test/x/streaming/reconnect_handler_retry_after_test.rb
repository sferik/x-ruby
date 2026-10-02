# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream that fails with a response that asks for a wait with a Retry-After header waits at least that long, as a
  # request a client sends again does, and raises at once for one that asks for longer than the maximum wait of the
  # client, as a rate limit that resets later does
  class ReconnectHandlerRetryAfterTest < Minitest::Test
    cover Streaming.const_get(:ReconnectHandler)

    def setup
      @sleeps = []
      @runs = 0
    end

    def test_a_server_error_waits_as_long_as_it_asks_when_that_is_longer_than_the_backoff
      assert_raises(ServiceUnavailable) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 4)) { refused(ServiceUnavailable, 503, "30") } }
      assert_equal [30, 30, 30, 40], @sleeps
    end

    def test_a_request_timeout_or_a_conflict_waits_as_long_as_it_asks
      assert_raises(Conflict) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 2)) { @runs.zero? ? refused(RequestTimeout, 408, "7") : refused(Conflict, 409, "9") } }
      assert_equal [7, 10], @sleeps
    end

    def test_a_server_error_that_asks_for_less_than_the_backoff_waits_for_the_backoff
      assert_raises(ServiceUnavailable) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 2)) { refused(ServiceUnavailable, 503, "1") } }
      assert_equal [5, 10], @sleeps
    end

    def test_a_server_error_that_asks_for_longer_than_the_maximum_wait_raises_at_once
      error = assert_raises(ServiceUnavailable) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_rate_limit_wait: 900)) { refused(ServiceUnavailable, 503, "901") } }

      assert_equal [901, 1, []], [error.retry_after, @runs, @sleeps]
    end

    def test_a_server_error_that_asks_for_as_long_as_the_maximum_wait_waits_for_it
      assert_raises(ServiceUnavailable) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 1, max_rate_limit_wait: 900)) { refused(ServiceUnavailable, 503, "900") } }
      assert_equal [2, [900]], [@runs, @sleeps]
    end

    def test_the_backoff_alone_waits_longer_than_the_maximum_wait_rather_than_raise
      assert_raises(ServiceUnavailable) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 3, max_rate_limit_wait: 6)) { refused(ServiceUnavailable, 503, nil) } }
      assert_equal [5, 10, 20], @sleeps
    end

    private

    def stream_with(handler, &stream)
      handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(object) { object }, &stream) }
    end

    def refused(error_class, status, retry_after)
      @runs += 1
      raise error_class.new(status:, headers: retry_after ? {"retry-after" => retry_after} : {})
    end
  end

  # A stream refused with a 503 that asks for a wait reconnects once it is over
  class StreamingClientRetryAfterTest < Minitest::Test
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def test_a_stream_refused_with_a_retry_after_reconnects_once_it_is_over
      stub_request(:get, STREAM_URL).to_return({status: 503, headers: {"Retry-After" => "120"}}, {body: "{\"data\":{\"id\":\"1\"}}\r\n"})
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
      sleeps = []
      post = streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(seconds) { sleeps << seconds }) do
        streaming_client.stream("tweets/sample/stream") { |json| break json.dig("data", "id") }
      end

      assert_equal ["1", [120]], [post, sleeps]
    end
  end
end
