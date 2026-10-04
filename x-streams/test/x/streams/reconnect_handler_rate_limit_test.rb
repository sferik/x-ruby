# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream refused for a rate limit backs off as X asks, waits for a limit that resets later, and raises for one that
  # resets later than the maximum wait of the client
  class ReconnectHandlerRateLimitTest < Minitest::Test
    cover Streams.const_get(:ReconnectHandler)

    USAGE_CAPPED = %({"title":"UsageCapExceeded","detail":"Usage cap exceeded: Monthly product cap","type":"https://api.twitter.com/2/problems/usage-capped","period":"Monthly","scope":"Product"})

    RATE_LIMITED = %({"title":"Too Many Requests","detail":"Too Many Requests","type":"about:blank","status":429})

    def setup
      @sleeps = []
      @runs = 0
    end

    def test_a_rate_limit_waits_until_it_resets_or_backs_off_from_a_minute
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_reconnects: 8, max_rate_limit_wait: 1000)) { refused((@runs > 2) ? 1000 : nil) } }
      assert_equal [60, 120, 240, 1000, 1000], @sleeps
    end

    def test_a_rate_limit_after_other_errors_backs_off_from_a_minute
      unavailable = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      errors = [NetworkError.new("dropped"), unavailable, NetworkError.new("dropped")]

      assert_raises(TooManyRequests) do
        stream_with(Streams.const_get(:ReconnectHandler).new(max_reconnects: 5)) { (error = errors[@runs]) ? (@runs += 1) && raise(error) : refused(nil) }
      end
      assert_equal [0.0, 5, 0.25, 60, 120], @sleeps
    end

    def test_a_rate_limit_that_resets_sooner_still_backs_off_from_a_minute
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_reconnects: 2)) { refused(10) } }
      assert_equal [60, 120], @sleeps
    end

    def test_a_rate_limit_that_resets_later_than_the_maximum_wait_raises_at_once
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_rate_limit_wait: 900)) { refused(901) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    def test_a_rate_limit_that_resets_as_late_as_the_maximum_wait_waits_for_it
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_reconnects: 1, max_rate_limit_wait: 900)) { refused(900) } }
      assert_equal [2, [900]], [@runs, @sleeps]
    end

    def test_a_rate_limit_backs_off_no_longer_than_the_maximum_wait
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_rate_limit_wait: 120)) { refused(nil) } }
      assert_equal [60, 120], @sleeps
    end

    def test_a_rate_limit_keeps_doubling_past_320_seconds_until_it_passes_the_maximum_wait
      assert_raises(TooManyRequests) { stream_with(Streams.const_get(:ReconnectHandler).new(max_reconnects: 10)) { refused(nil) } }
      assert_equal [60, 120, 240, 480], @sleeps
    end

    def test_the_maximum_wait_defaults_to_that_of_a_client
      assert_equal Client::DEFAULT_MAX_RATE_LIMIT_WAIT, Streams.const_get(:ReconnectHandler).new.max_rate_limit_wait
    end

    def test_the_usage_cap_of_the_project_raises_at_once
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 8, max_rate_limit_wait: 1000)

      assert_raises(TooManyRequests) { stream_with(handler) { (@runs += 1) && raise(TooManyRequests.new(status: 429, headers: {"content-type" => "application/problem+json"}, body: USAGE_CAPPED)) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    def test_a_refusal_that_names_a_problem_other_than_the_usage_cap_reconnects
      handler = Streams.const_get(:ReconnectHandler).new(max_reconnects: 1)

      assert_raises(TooManyRequests) { stream_with(handler) { (@runs += 1) && raise(TooManyRequests.new(status: 429, headers: {"content-type" => "application/problem+json"}, body: RATE_LIMITED)) } }
      assert_equal [2, [60]], [@runs, @sleeps]
    end

    private

    def stream_with(handler, &stream)
      Time.stub(:now, Time.utc(1983, 11, 24)) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(object) { object }, &stream) }
      end
    end

    def refused(reset_in)
      @runs += 1
      response = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => (Time.now.to_i + reset_in).to_s}.each { |name, value| response[name] = value } if reset_in
      raise TooManyRequests.new(http_response: response)
    end
  end
end
