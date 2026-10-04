# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What a stream reads starts the counts of its reconnects over only once its connection has been open for a minute,
  # so that a stream whose connections each deliver something and drop backs off, and runs out of reconnects
  class ReconnectHandlerStableConnectionTest < Minitest::Test
    cover Streams.const_get(:ReconnectHandler)

    def setup
      @sleeps = []
      @runs = 0
      @delivered = []
      @clock = 100.0
    end

    def test_a_keep_alive_read_from_a_connection_open_for_a_minute_starts_every_count_over
      errors = [ServiceUnavailable, NetworkError, nil, ServiceUnavailable, NetworkError]
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 2)

      assert_raises(NetworkError) { stream_with(handler) { |_deliver, alive| fail_with(errors.fetch(@runs) || after(60) { alive.call } && NetworkError) } }
      assert_equal [5, 0.0, 0.0, 5], @sleeps
    end

    def test_an_object_read_from_a_connection_open_for_a_minute_starts_the_count_over
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 1)
      assert_raises(NetworkError) do
        stream_with(handler) do |deliver|
          after(60) { deliver.call(@runs + 1) } if @runs < 3
          fail_with(NetworkError)
        end
      end

      assert_equal [[1, 2, 3], 4, [0.0, 0.0, 0.0]], [@delivered, @runs, @sleeps]
    end

    def test_a_keep_alive_read_from_a_connection_open_for_longer_than_a_minute_starts_the_count_over
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 1)

      assert_raises(NetworkError) do
        stream_with(handler) do |_deliver, alive|
          after(3600) { alive.call } if @runs < 3
          fail_with(NetworkError)
        end
      end

      assert_equal [4, [0.0, 0.0, 0.0], []], [@runs, @sleeps, @delivered]
    end

    # A server that delivers an object, or a keep-alive, and closes would otherwise be reconnected to at once, without
    # end, whatever max_reconnects is, which spends the connections X allows a stream in a window
    def test_what_a_connection_younger_than_a_minute_reads_starts_no_count_over
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 3)

      assert_raises(NetworkError) do
        stream_with(handler) do |deliver, alive|
          after(59.9) { deliver.call(@runs) && alive.call }
          fail_with(NetworkError)
        end
      end

      assert_equal [[0, 1, 2, 3], 4, [0.0, 0.25, 0.5]], [@delivered, @runs, @sleeps]
    end

    def test_a_connection_that_delivers_an_object_and_drops_backs_off_as_one_that_delivers_nothing_does
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 70)

      assert_raises(NetworkError) { stream_with(handler) { |deliver| deliver.call(@runs) && fail_with(NetworkError) } }
      assert_equal [71, [0.0, 0.25, 0.5], [16] * 5], [@runs, @sleeps.first(3), @sleeps.last(5)]
    end

    # The minute is counted from when the connection that reads was opened, not from when the stream was first run
    def test_the_minute_of_a_connection_is_counted_from_when_it_was_opened
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 2)

      assert_raises(NetworkError) do
        stream_with(handler) do |_deliver, alive|
          after(1) { alive.call }
          @clock += 60
          fail_with(NetworkError)
        end
      end

      assert_equal [3, [0.0, 0.25]], [@runs, @sleeps]
    end

    def test_the_minute_of_a_connection_is_counted_on_a_clock_that_never_runs_back
      handler = Streams.const_get(:ReconnectHandler).new
      clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_in_delta clock, handler.__send__(:now), 5
      assert_operator handler.__send__(:now), :>=, clock
    end

    private

    # Run a stream on a clock the test sets, rather than the clock of the system, so that a connection is as old as
    # the test says, without waiting
    def stream_with(handler, &stream)
      handler.stub(:now, -> { @clock }) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(object) { @delivered << object }, &stream) }
      end
    end

    # Read from a connection once it has been open for the seconds given
    def after(seconds)
      @clock += seconds
      yield
    end

    def fail_with(error_class)
      @runs += 1
      raise error_class.new("dropped") if error_class <= NetworkError

      raise error_class.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
    end
  end
end
