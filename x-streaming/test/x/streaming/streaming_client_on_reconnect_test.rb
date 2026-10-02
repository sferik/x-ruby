# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A streaming client passes on_reconnect the error that dropped a stream and the wait before each reconnect, which
  # gives up on the stream by stopping the streaming client, or stops it by raising
  class StreamingClientOnReconnectTest < Minitest::Test
    cover StreamingClient
    cover Streaming.const_get(:Validator)
    cover Streaming.const_get(:ReconnectHandler)

    HANDLER = Streaming.const_get(:ReconnectHandler)
    DROPPED = NetworkError.new("dropped")
    UNAVAILABLE = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))

    def setup
      @reconnects, @sleeps = [], []
      @started, @resume = Queue.new, Queue.new
    end

    def test_a_streaming_client_has_no_on_reconnect_by_default
      assert_nil Client.new.streaming.on_reconnect
      assert_nil StreamingClient.new(Client.new).on_reconnect
    end

    def test_a_streaming_client_takes_an_on_reconnect
      on_reconnect = ->(_error, _wait) {}

      assert_same on_reconnect, Client.new.streaming(on_reconnect:).on_reconnect
      assert_same on_reconnect, StreamingClient.new(Client.new, on_reconnect:).on_reconnect
    end

    def test_an_on_reconnect_that_does_not_respond_to_call_is_refused_when_the_streaming_client_is_built
      error = assert_raises(ArgumentError) { Client.new.streaming(on_reconnect: "log") }

      assert_equal "on_reconnect must respond to call, as a Proc or a lambda does, or be nil, not a String", error.message
    end

    def test_on_reconnect_is_passed_the_error_and_the_wait_before_each_reconnect
      handler = HANDLER.new(max_reconnects: 2, on_reconnect: ->(error, wait) { @reconnects << [error, wait, @sleeps.size] })

      assert_raises(NetworkError) { stream_with(handler) { raise [DROPPED, UNAVAILABLE].fetch(@reconnects.size, DROPPED) } }
      assert_equal [[DROPPED, 0.0, 0], [UNAVAILABLE, 5, 1]], @reconnects
      assert_equal [0.0, 5], @sleeps
    end

    def test_on_reconnect_is_passed_no_error_for_a_stream_that_ended_without_one
      handler = HANDLER.new(max_reconnects: 1, on_reconnect: ->(error, wait) { @reconnects << [error, wait] })

      assert_nil stream_with(handler) { nil }
      assert_equal [[nil, 0.0]], @reconnects
    end

    def test_an_error_on_reconnect_raises_stops_the_stream_and_reaches_the_caller_as_it_was_raised
      failure = NetworkError.new("the log could not be written")
      handler = HANDLER.new(on_reconnect: ->(_error, _wait) { raise failure })

      assert_same failure, assert_raises(NetworkError) { stream_with(handler) { raise NetworkError, "dropped" } }
      assert_empty @sleeps
    end

    def test_an_error_on_reconnect_raises_for_a_stream_that_ended_without_one_is_not_reconnected_after
      runs = []
      handler = HANDLER.new(max_reconnects: 2, on_reconnect: ->(_error, _wait) { raise DROPPED if (@reconnects << 1).one? })

      assert_same DROPPED, assert_raises(NetworkError) { stream_with(handler) { runs << 1 } }
      assert_equal [[1], []], [runs, @sleeps]
    end

    def test_a_stream_that_cannot_connect_is_given_up_on_by_stopping_the_streaming_client_from_on_reconnect
      streaming = nil
      streaming = unreachable.streaming(on_reconnect: ->(error, wait) { (@reconnects << [error.class, wait]) && streaming.stop })

      assert_nil stream(streaming)
      assert_equal [[NetworkError, 0.0]], @reconnects
    end

    def test_an_on_reconnect_that_runs_when_the_stream_is_stopped_runs_to_its_end
      streaming = unreachable.streaming(on_reconnect: ->(error, _wait) { (@started << true) && @resume.pop && (@reconnects << error.class) })
      reader = Thread.new { stream(streaming) }
      stop_while_paused(streaming)

      assert_equal [nil, [NetworkError]], [reader.value, @reconnects]
    end

    def test_an_error_on_reconnect_raises_for_a_stream_that_cannot_connect_reaches_the_caller
      streaming = unreachable.streaming(on_reconnect: ->(error, _wait) { raise ArgumentError, "gave up: #{error.class}" })
      error = assert_raises(ArgumentError) { stream(streaming) }

      assert_equal "gave up: X::NetworkError", error.message
    end

    private

    # Stop a streaming client while the on_reconnect that pauses it runs, and resume it
    def stop_while_paused(streaming)
      @started.pop
      streaming.stop
      @resume << true
    end

    # Run a stream of a streaming client, which delivers nothing, with webmock disabled
    def stream(streaming) = without_webmock { streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }

    # Run a stream with the handler, noting each wait rather than waiting
    def stream_with(handler, &)
      handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(_object) {}, &) }
    end

    # A client of a port of the loopback interface nothing listens on, which refuses each connection
    def unreachable
      port = TCPServer.open("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }
      Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/")
    end

    # Run a block with webmock disabled, so that a stream connects to the loopback interface
    def without_webmock
      WebMock.disable!
      yield
    ensure
      WebMock.enable!
    end
  end
end
