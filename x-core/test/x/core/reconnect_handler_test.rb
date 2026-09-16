require_relative "../../test_helper"

module X
  class ReconnectHandlerTest < Minitest::Test
    cover ReconnectHandler

    def setup
      @sleeps = []
      @runs = 0
      @delivered = []
    end

    def test_reconnects_without_limit_by_default
      assert_equal Float::INFINITY, ReconnectHandler.new.max_reconnects
    end

    def test_a_stream_that_ends_reconnects_at_once_then_backs_off_linearly
      assert_nil stream_with(ReconnectHandler.new(max_reconnects: 3)) { @runs += 1 }
      assert_equal [4, [0.0, 0.25, 0.5]], [@runs, @sleeps]
    end

    def test_a_dropped_connection_backs_off_linearly_up_to_16_seconds_then_raises
      handler = ReconnectHandler.new(max_reconnects: 1)
      handler.max_reconnects = 70

      assert_raises(NetworkError) { stream_with(handler) { fail_with(NetworkError) } }
      assert_equal [71, [0.0, 0.25, 0.5], [16] * 5], [@runs, @sleeps.first(3), @sleeps.last(5)]
      assert_in_delta 15.75, @sleeps[63]
    end

    def test_a_server_error_or_a_refused_connection_backs_off_exponentially_up_to_320_seconds
      assert_raises(ServiceUnavailable) { stream_with(ReconnectHandler.new(max_reconnects: 8)) { fail_with(@runs.even? ? ServiceUnavailable : Conflict) } }
      assert_equal [5, 10, 20, 40, 80, 160, 320, 320], @sleeps
    end

    def test_a_line_that_is_not_json_backs_off_exponentially
      assert_raises(InvalidResponse) { stream_with(ReconnectHandler.new(max_reconnects: 3)) { fail_with(InvalidResponse) } }
      assert_equal [4, [5, 10, 20]], [@runs, @sleeps]
    end

    def test_a_rate_limit_waits_until_it_resets_or_backs_off_from_a_minute
      assert_raises(TooManyRequests) { stream_with(ReconnectHandler.new(max_reconnects: 8)) { refused((@runs > 2) ? 1000 : nil) } }
      assert_equal [60, 120, 240, 1000, 1000, 1000, 1000, 1000], @sleeps
    end

    def test_delivering_an_object_starts_the_count_over
      handler = ReconnectHandler.new(max_reconnects: 1)
      stream_with(handler) do |deliver|
        @runs += 1
        deliver.call(@runs) if @runs <= 3
      end

      assert_equal [[1, 2, 3], 4, [0.0, 0.0, 0.0]], [@delivered, @runs, @sleeps]
    end

    def test_an_error_from_the_consumer_stops_the_stream
      consumer = ->(_) { raise NetworkError, "the consumer's own request failed" }
      handler = ReconnectHandler.new

      error = assert_raises(NetworkError) { handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(consumer) { |deliver| deliver.call(1) } } }
      assert_equal ["the consumer's own request failed", []], [error.message, @sleeps]
      assert_instance_of NetworkError, error
    end

    def test_other_errors_raise_at_once
      assert_raises(Unauthorized) { stream_with(ReconnectHandler.new) { fail_with(Unauthorized) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    private

    def stream_with(handler, &stream)
      Time.stub(:now, Time.utc(1983, 11, 24)) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(object) { @delivered << object }, &stream) }
      end
    end

    def refused(reset_in)
      @runs += 1
      response = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => (Time.now.to_i + reset_in).to_s}.each { |name, value| response[name] = value } if reset_in
      raise TooManyRequests.new(response:)
    end

    def fail_with(error_class)
      @runs += 1
      raise error_class.new("dropped") if error_class <= NetworkError

      raise error_class.new(response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
    end
  end
end
