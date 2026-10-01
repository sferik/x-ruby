# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ReconnectHandlerTest < Minitest::Test
    cover Streaming.const_get(:ReconnectHandler)

    def setup
      @sleeps = []
      @runs = 0
      @delivered = []
    end

    def test_reconnects_without_limit_by_default
      assert_equal Float::INFINITY, Streaming.const_get(:ReconnectHandler).new.max_reconnects
    end

    def test_a_stream_that_ends_reconnects_at_once_then_backs_off_linearly
      assert_nil stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 3)) { @runs += 1 }
      assert_equal [4, [0.0, 0.25, 0.5]], [@runs, @sleeps]
    end

    def test_a_dropped_connection_backs_off_linearly_up_to_16_seconds_then_raises
      handler = Streaming.const_get(:ReconnectHandler).new(max_reconnects: 70)

      assert_raises(NetworkError) { stream_with(handler) { fail_with(NetworkError) } }
      assert_equal [71, [0.0, 0.25, 0.5], [16] * 5], [@runs, @sleeps.first(3), @sleeps.last(5)]
      assert_in_delta 15.75, @sleeps[63]
    end

    def test_a_server_error_a_request_timeout_or_a_conflict_backs_off_exponentially_up_to_320_seconds
      assert_raises(Conflict) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 8)) { fail_with([ServiceUnavailable, RequestTimeout, Conflict].fetch(@runs % 3)) } }
      assert_equal [5, 10, 20, 40, 80, 160, 320, 320], @sleeps
    end

    def test_a_line_that_is_not_json_backs_off_exponentially
      assert_raises(InvalidResponse) { stream_with(Streaming.const_get(:ReconnectHandler).new(max_reconnects: 3)) { fail_with(InvalidResponse) } }
      assert_equal [4, [5, 10, 20]], [@runs, @sleeps]
    end

    def test_delivering_an_object_starts_the_count_over
      handler = Streaming.const_get(:ReconnectHandler).new(max_reconnects: 1)
      stream_with(handler) do |deliver|
        @runs += 1
        deliver.call(@runs) if @runs <= 3
      end

      assert_equal [[1, 2, 3], 4, [0.0, 0.0, 0.0]], [@delivered, @runs, @sleeps]
    end

    def test_reading_a_keep_alive_starts_the_count_over
      handler = Streaming.const_get(:ReconnectHandler).new(max_reconnects: 1)

      assert_nil stream_with(handler) { |_deliver, alive| alive.call if (@runs += 1) <= 3 }
      assert_equal [4, [0.0, 0.0, 0.0], []], [@runs, @sleeps, @delivered]
    end

    def test_an_error_from_the_consumer_stops_the_stream
      consumer = ->(_) { raise NetworkError, "the consumer's own request failed" }
      handler = Streaming.const_get(:ReconnectHandler).new

      error = assert_raises(NetworkError) { handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(consumer) { |deliver| deliver.call(1) } } }
      assert_equal ["the consumer's own request failed", []], [error.message, @sleeps]
      assert_instance_of NetworkError, error
    end

    # Kernel#loop rescues StopIteration, so a stream run again in one would end and return, and a consumer that
    # exhausted an Enumerator of its own would never hear of it.
    def test_a_stop_iteration_from_the_consumer_reaches_the_caller
      consumer = ->(_) { [].each.next }
      handler = Streaming.const_get(:ReconnectHandler).new

      assert_raises(StopIteration) { handler.handle(consumer) { |deliver| deliver.call(1) } }
    end

    def test_a_stop_iteration_from_the_stream_itself_reaches_the_caller
      assert_raises(StopIteration) { Streaming.const_get(:ReconnectHandler).new.handle(->(_) {}) { |_deliver| [].each.next } }
    end

    def test_a_consumer_stops_the_stream_by_breaking_out_of_its_block
      assert_equal 1, streaming(Streaming.const_get(:ReconnectHandler).new) { |object| break object }
      assert_empty @sleeps
    end

    def test_a_consumer_stops_the_stream_by_throwing
      handler = Streaming.const_get(:ReconnectHandler).new
      caught = catch(:done) { handler.handle(->(object) { throw :done, object }) { |deliver| deliver.call(1) } }

      assert_equal 1, caught
    end

    def test_other_errors_raise_at_once
      assert_raises(Unauthorized) { stream_with(Streaming.const_get(:ReconnectHandler).new) { fail_with(Unauthorized) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    private

    # The consumer of a stream is the block its caller passed, as StreamingClient#stream is given one, so a break
    # in it ends the method that was given the block, which a lambda of a test would not show.
    def streaming(handler, &consumer)
      handler.handle(consumer) { |deliver| deliver.call(1) }
    end

    def stream_with(handler, &stream)
      Time.stub(:now, Time.utc(1983, 11, 24)) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(object) { @delivered << object }, &stream) }
      end
    end

    def fail_with(error_class)
      @runs += 1
      raise error_class.new("dropped") if error_class <= NetworkError

      raise error_class.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
    end
  end

  class ReconnectHandlerCallbackTest < Minitest::Test
    cover Streaming.const_get(:ReconnectHandler)

    def test_an_error_a_callback_raised_stops_the_stream_and_reaches_the_caller_as_it_was_raised
      failure = NetworkError.new("the hook's own request failed")
      runs = []
      stream = proc { raise Streaming.const_get(:CallbackError), failure.tap { runs << 1 } }
      handler = Streaming.const_get(:ReconnectHandler).new
      error = handler.stub(:sleep, ->(_seconds) { flunk "unexpected reconnect" }) { assert_raises(NetworkError) { handler.handle(->(_) {}, &stream) } }

      assert_equal [failure, [1]], [error, runs]
    end
  end
end
