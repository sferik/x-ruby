# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RateLimitHandlerTest < Minitest::Test
    cover Core::RateLimitHandler

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_defaults
      handler = Core::RateLimitHandler.new

      assert_equal [0, 900], [handler.max_rate_limit_retries, handler.max_rate_limit_wait]
    end

    def test_returns_what_the_block_returns
      assert_equal :done, handle(Core::RateLimitHandler.new) { :done }
    end

    def test_retries_nothing_by_default_and_reads_no_reset
      error = assert_raises(TooManyRequests) { handle(Core::RateLimitHandler.new) { refuse(headers: {"x-rate-limit-remaining" => "0"}) } }

      assert_equal [1, []], [@attempts, @sleeps]
      assert_equal 429, error.status
    end

    def test_retries_after_waiting_for_the_reset
      result = handle(Core::RateLimitHandler.new(max_rate_limit_retries: 2)) { (@attempts < 2) ? refuse(reset_in: 30) : @attempts += 1 }

      assert_equal [3, [30, 30]], [result, @sleeps]
    end

    def test_raises_the_error_once_the_retries_run_out
      handler = Core::RateLimitHandler.new(max_rate_limit_retries: 1)

      assert_raises(TooManyRequests) { handle(handler) { refuse(reset_in: 0) } }
      assert_equal [2, [0]], [@attempts, @sleeps]
    end

    def test_raises_at_once_when_the_limit_resets_after_the_maximum_wait
      handler = Core::RateLimitHandler.new(max_rate_limit_retries: 3, max_rate_limit_wait: 10)

      assert_raises(TooManyRequests) { handle(handler) { refuse(reset_in: 11) } }
      assert_equal [1, []], [@attempts, @sleeps]
      assert_raises(TooManyRequests) { handle(Core::RateLimitHandler.new(max_rate_limit_retries: 1, max_rate_limit_wait: 10)) { refuse(reset_in: 10) } }
      assert_equal [3, [10]], [@attempts, @sleeps]
    end

    def test_a_refusal_without_a_reset_time_waits_a_minute_and_doubles_the_wait
      handler = Core::RateLimitHandler.new(max_rate_limit_retries: 5, max_rate_limit_wait: 240)

      assert_raises(TooManyRequests) { handle(handler) { refuse(headers: {"x-rate-limit-remaining" => "0"}) } }
      assert_equal [4, [60, 120, 240]], [@attempts, @sleeps]
    end

    def test_adds_a_random_share_of_five_seconds_to_each_wait
      result = handle(Core::RateLimitHandler.new(max_rate_limit_retries: 2), random: 0.5) { (@attempts < 2) ? refuse(reset_in: 30) : @attempts += 1 }

      assert_equal [3, [32.5, 32.5]], [result, @sleeps]
    end

    def test_measures_the_maximum_wait_against_the_reset_rather_than_the_random_share
      handler = Core::RateLimitHandler.new(max_rate_limit_retries: 1, max_rate_limit_wait: 10)

      assert_raises(TooManyRequests) { handle(handler, random: 1.0) { refuse(reset_in: 10) } }
      assert_equal [2, [15]], [@attempts, @sleeps]
    end

    private

    # Run the block, collecting the waits, with the random share added to each one fixed
    def handle(handler, random: 0.0, &)
      Time.stub(:now, Time.utc(1983, 11, 24)) do
        handler.stub(:rand, random) do
          handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(&) }
        end
      end
    end

    def refuse(reset_in: nil, headers: {})
      @attempts += 1
      response = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      headers = {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => (Time.now.to_i + reset_in).to_s} if reset_in
      headers.each { |name, value| response[name] = value }
      raise TooManyRequests.new(http_response: response)
    end
  end
end
