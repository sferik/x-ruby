# frozen_string_literal: true

require "json"
require_relative "../../test_helper"
require_relative "stream_error_test"

module X
  # A stream reconnects after a line that holds operational-disconnects alone, as it does after a connection that
  # dropped, and stops after a line that holds any other error
  class StreamDisconnectTest < Minitest::Test
    cover Streaming.const_get(:ReconnectHandler)
    cover Streaming.const_get(:StreamParser)

    STREAM_URL = "https://api.x.com/2/tweets/search/stream"
    DISCONNECT = StreamErrorTest::DISCONNECT
    DISCONNECT_LINE = StreamErrorTest::DISCONNECT_LINE
    REFUSAL = StreamErrorTest::REFUSAL
    DataBuilder = StreamErrorTest::DataBuilder

    REFUSAL_LINE = StreamErrorTest::REFUSAL_LINE

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      @runs = 0
      @sleeps = []
    end

    def test_a_line_that_holds_a_disconnect_beside_other_errors_is_not_reconnected_after
      stub_request(:get, STREAM_URL).to_return(body: "#{JSON.generate({"errors" => [DISCONNECT, REFUSAL]})}\r\n")
      streaming_client = @client.streaming(max_reconnects: 3)

      error = assert_raises(StreamError) do
        streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(_) { flunk "unexpected reconnect" }) do
          streaming_client.stream("tweets/search/stream") { flunk "unexpected yield" }
        end
      end
      assert_equal [DISCONNECT, REFUSAL], error.problems.map(&:to_h)
    end

    def test_a_disconnect_reconnects_at_once
      stub_request(:get, STREAM_URL).to_return({body: DISCONNECT_LINE}, {body: "{\"data\":{\"id\":\"1\"}}\r\n"})
      streaming_client = @client.streaming(max_reconnects: 1)
      waits = []

      post = streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(seconds) { waits << seconds }) do
        streaming_client.stream("tweets/search/stream") { |json| break json }
      end

      assert_equal({"data" => {"id" => "1"}}, post)
      assert_equal [0], waits
      assert_requested :get, STREAM_URL, times: 2
    end

    def test_a_disconnect_backs_off_as_a_dropped_connection_does
      stub_request(:get, STREAM_URL).to_return(body: DISCONNECT_LINE)
      streaming_client = @client.streaming(max_reconnects: 3)
      waits = []

      streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(seconds) { waits << seconds }) do
        assert_raises(StreamError) { streaming_client.stream("tweets/search/stream", object_class: DataBuilder) { flunk "unexpected yield" } }
      end
      assert_equal [0, 0.25, 0.5], waits
      assert_requested :get, STREAM_URL, times: 4
    end

    def test_a_disconnect_raises_with_no_reconnects_left
      stub_request(:get, STREAM_URL).to_return(body: DISCONNECT_LINE)

      error = assert_raises(StreamError) { @client.streaming(max_reconnects: 0).stream("tweets/search/stream") { flunk "unexpected yield" } }
      assert_equal [DISCONNECT], error.problems.map(&:to_h)
      assert_requested :get, STREAM_URL, times: 1
    end

    def test_a_line_of_disconnects_backs_off_linearly_then_raises
      disconnect = Problem.new({"type" => "https://api.x.com/2/problems/operational-disconnect"})

      assert_raises(StreamError) do
        handle(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 3)) do
          @runs += 1
          raise StreamError.new([disconnect])
        end
      end
      assert_equal [4, [0.0, 0.25, 0.5]], [@runs, @sleeps]
    end

    def test_a_line_of_other_errors_raises_at_once_from_a_subclass_too
      refusal = Problem.new({"type" => "https://api.x.com/2/problems/streaming-connection"})

      [StreamError, Class.new(StreamError)].each do |error_class|
        assert_raises(error_class) { handle(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 3)) { raise error_class.new([refusal]) } }
      end
      assert_empty @sleeps
    end

    def test_a_stream_error_is_not_swallowed_by_a_reconnect
      stub_request(:get, STREAM_URL).to_return(body: REFUSAL_LINE)
      streaming_client = @client.streaming(max_reconnects: 3)

      assert_raises(StreamError) do
        streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(_) { flunk "unexpected reconnect" }) do
          streaming_client.stream("tweets/search/stream", object_class: DataBuilder) { flunk "unexpected yield" }
        end
      end
      assert_requested :get, STREAM_URL, times: 1
    end

    private

    def handle(handler, &stream)
      handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(_) {}, &stream) }
    end
  end
end
