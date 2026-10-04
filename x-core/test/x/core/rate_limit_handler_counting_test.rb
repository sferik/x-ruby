# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The retries of a request for a rate limit are counted across its attempts, apart from those of a request one of
  # its callbacks sends, and handed down across the attempts Client#with_retries sends
  class RateLimitHandlerCountingTest < Minitest::Test
    cover Core.const_get(:RateLimitHandler)

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_counting_counts_the_retries_of_each_attempt_as_retries_of_one_request
      handler = Core.const_get(:RateLimitHandler).new(max_rate_limit_retries: 1)
      handler.counting do
        handle(handler) { (@attempts < 1) ? refuse(reset_in: 1) : :done }

        assert_raises(TooManyRequests) { handle(handler) { refuse(reset_in: 1) } }
      end

      assert_equal [2, 1], [@attempts, @sleeps.size]
    end

    def test_counting_within_counting_counts_afresh_and_leaves_the_outer_count_as_it_was
      handler = Core.const_get(:RateLimitHandler).new(max_rate_limit_retries: 1)
      handler.counting do
        handle(handler) { (@attempts < 1) ? refuse(reset_in: 1) : :done }

        assert_equal :done, handler.counting { handle(handler) { (@attempts < 2) ? refuse(reset_in: 1) : :done } }
        refused_at_once(handler)
      end

      assert_equal [2, nil], [@sleeps.size, Thread.current[Core.const_get(:RateLimitHandler)::RETRIES]]
    end

    def test_handing_down_counts_on_across_the_requests_it_wraps
      handler = Core.const_get(:RateLimitHandler).new(max_rate_limit_retries: 1)
      handler.handing_down do
        handler.counting { handle(handler) { (@attempts < 1) ? refuse(reset_in: 1) : :done } }

        assert_equal :raised, handler.counting { refused_at_once(handler) && :raised }
      end

      assert_equal [1, nil], [@sleeps.size, Thread.current[Core.const_get(:RateLimitHandler)::HANDED]]
    end

    def test_a_request_within_a_request_with_retries_wraps_does_not_take_the_retries_handed_down
      handler = Core.const_get(:RateLimitHandler).new(max_rate_limit_retries: 1)
      handler.handing_down do
        handler.counting { handle(handler) { (@attempts < 1) ? refuse(reset_in: 1) : :done } }

        assert_equal :done, handler.counting { handler.counting { handle(handler) { (@attempts < 2) ? refuse(reset_in: 1) : :done } } }
      end

      assert_equal 2, @sleeps.size
    end

    def test_handing_down_within_handing_down_leaves_the_outer_retries_as_they_were
      handler = Core.const_get(:RateLimitHandler).new(max_rate_limit_retries: 1)
      handler.handing_down do
        handler.counting { handle(handler) { (@attempts < 1) ? refuse(reset_in: 1) : :done } }
        handler.handing_down { handler.counting { :done } }

        handler.counting { refused_at_once(handler) }
      end

      assert_equal 1, @sleeps.size
    end

    private

    def refused_at_once(handler)
      assert_raises(TooManyRequests) { handle(handler) { refuse(reset_in: 1) } }
    end

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
