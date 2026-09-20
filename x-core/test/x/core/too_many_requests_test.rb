# frozen_string_literal: true

require_relative "../../test_helper"

# Build a 429 that reports a 15-minute limit and a 24-hour app limit, both used up
module RateLimitedResponse
  def rate_limited_error
    response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")

    rate_limit(response)
    app_limit(response)
    user_limit(response)

    X::TooManyRequests.new(response:)
  end

  def rate_limit(response)
    Time.stub :now, Time.utc(1983, 11, 24) do
      response["x-rate-limit-reset"] = (Time.now + 60).to_i.to_s
    end
    response["x-rate-limit-limit"] = "100"
    response["x-rate-limit-remaining"] = "0"
  end

  def app_limit(response)
    Time.stub :now, Time.utc(1983, 11, 24) do
      response["x-app-limit-24hour-reset"] = (Time.now + 61).to_i.to_s
    end
    response["x-app-limit-24hour-limit"] = "100"
    response["x-app-limit-24hour-remaining"] = "0"
  end

  def user_limit(response)
    Time.stub :now, Time.utc(1983, 11, 24) do
      response["x-user-limit-24hour-remaining"] = (Time.now + 60).to_i.to_s
    end
    response["x-user-limit-24hour-reset"] = "100"
    response["x-user-limit-24hour-reset"] = "0"
  end
end

module X
  class TooManyRequestsTest < Minitest::Test
    include RateLimitedResponse

    cover TooManyRequests

    def setup
      @exception = rate_limited_error
    end

    def test_initialize_with_empty_response
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      exception = TooManyRequests.new(response:)

      assert_equal 0, exception.rate_limits.count
      assert_nil exception.reset_at
      assert_nil exception.reset_in
      assert_nil exception.retry_after
      assert_equal "Too Many Requests", exception.message
    end

    def test_rate_limit_is_the_fifteen_minute_limit
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal ["rate-limit", Time.now + 60], [@exception.rate_limit.type, @exception.rate_limit.reset_at]
      end
    end

    def test_rate_limit_is_nothing_without_a_fifteen_minute_limit
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      app_limit(response)

      assert_nil TooManyRequests.new(response:).rate_limit
    end

    def test_rate_limits
      limits = @exception.rate_limits

      assert_equal 2, limits.count
      assert_equal "rate-limit", limits.first.type
      assert_equal "app-limit-24hour", limits.last.type
    end

    def test_rate_limits_include_the_limits_with_requests_left
      @exception.response["x-app-limit-24hour-remaining"] = "1"

      assert_equal %w[rate-limit app-limit-24hour], @exception.rate_limits.map(&:type)
    end

    def test_rate_limits_are_read_once
      assert_same @exception.rate_limits, @exception.rate_limits
    end

    def test_exhausted_rate_limits_leave_out_the_limits_with_requests_left
      @exception.response["x-rate-limit-remaining"] = "3"

      assert_equal ["app-limit-24hour"], @exception.exhausted_rate_limits.map(&:type)
    end

    def test_limiting_rate_limit_is_the_exhausted_limit_that_resets_last
      assert_equal "app-limit-24hour", @exception.limiting_rate_limit.type
    end

    def test_limiting_rate_limit_is_nothing_when_no_limit_is_exhausted
      @exception.response["x-rate-limit-remaining"] = "3"
      @exception.response["x-app-limit-24hour-remaining"] = "1"

      assert_nil @exception.limiting_rate_limit
    end
  end

  class TooManyRequestsResetTest < Minitest::Test
    include RateLimitedResponse

    cover TooManyRequests

    def setup
      @exception = rate_limited_error
    end

    def test_reset_at
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["x-app-limit-24hour-remaining"] = "0"
        @exception.response["x-app-limit-24hour-reset"] = (Time.now + 200).to_i.to_s

        assert_equal Time.at(Time.now.to_i + 200), @exception.reset_at
      end
    end

    def test_reset_in
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["x-app-limit-24hour-remaining"] = "0"
        @exception.response["x-app-limit-24hour-reset"] = (Time.now + 200).to_i.to_s

        assert_equal 200, @exception.reset_in
      end
    end

    def test_reset_in_is_never_negative
      @exception.response["x-rate-limit-reset"] = (Time.now - 60).to_i.to_s
      @exception.response["x-app-limit-24hour-reset"] = (Time.now - 61).to_i.to_s

      assert_equal 0, @exception.reset_in
    end

    def test_reset_in_ceil
      Time.stub :now, Time.utc(1983, 11, 24, 0, 0, 0, 900_000) do
        @exception.response["x-rate-limit-reset"] = (Time.now + 62).to_i.to_s

        assert_equal 62, @exception.reset_in
      end
    end

    def test_retry_after
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["x-app-limit-24hour-remaining"] = "0"
        @exception.response["x-app-limit-24hour-reset"] = (Time.now + 200).to_i.to_s

        assert_equal 200, @exception.retry_after
      end
    end

    def test_retry_after_waits_for_a_daily_limit_the_fifteen_minute_limit_has_not_reached
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["x-rate-limit-remaining"] = "3"
        @exception.response["x-app-limit-24hour-reset"] = (Time.now + 200).to_i.to_s

        assert_equal 200, @exception.retry_after
      end
    end
  end

  class TooManyRequestsRetryAfterHeaderTest < Minitest::Test
    include RateLimitedResponse

    cover TooManyRequests

    def setup
      @exception = rate_limited_error
    end

    def test_retry_after_counts_the_seconds_the_header_asks_for
      @exception.response["retry-after"] = "42"

      assert_equal 42, @exception.retry_after
    end

    def test_retry_after_counts_a_padded_header_in_tens_rather_than_eights
      @exception.response["retry-after"] = "060"

      assert_equal 60, @exception.retry_after
    end

    def test_retry_after_prefers_the_header_to_the_reset_time_of_the_limit
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["retry-after"] = "42"

        assert_equal [42, 61], [@exception.retry_after, @exception.reset_in]
      end
    end

    def test_retry_after_waits_until_the_time_the_header_names
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["retry-after"] = (Time.now + 300).httpdate

        assert_equal 300, @exception.retry_after
      end
    end

    def test_retry_after_waits_out_the_part_of_a_second_an_http_date_leaves_off
      Time.stub :now, Time.utc(1983, 11, 24, 0, 0, 0, 900_000) do
        @exception.response["retry-after"] = (Time.now + 62).httpdate

        assert_equal 62, @exception.retry_after
      end
    end

    def test_retry_after_is_never_negative_for_a_time_that_has_passed
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["retry-after"] = (Time.now - 300).httpdate

        assert_equal 0, @exception.retry_after
      end
    end

    def test_retry_after_falls_back_on_the_reset_time_for_a_header_that_says_no_time
      Time.stub :now, Time.utc(1983, 11, 24) do
        @exception.response["retry-after"] = "whenever you like"

        assert_equal 61, @exception.retry_after
      end
    end

    def test_retry_after_is_nothing_when_a_response_reports_no_limit_and_names_no_time
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      response["retry-after"] = "whenever you like"

      assert_nil TooManyRequests.new(response:).retry_after
    end
  end
end
