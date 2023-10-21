require_relative "../test_helper"

module X
  class TooManyRequestsTest < Minitest::Test
    cover TooManyRequests

    def setup
      rate_limit_headers = {
        "x-rate-limit-limit" => "100",
        "x-rate-limit-remaining" => "0",
        "x-rate-limit-reset" => (Time.now + 60).to_i.to_s
      }
      @exception = TooManyRequests.new("Rate Limit Exceeded", rate_limit_headers)
    end

    def test_initialize_with_empty_response
      msg = "Rate Limit Exceeded"
      exception = TooManyRequests.new(msg, {})

      assert_equal 0, exception.limit
      assert_equal 0, exception.remaining
      assert_equal Time.at(0).utc, exception.reset_at
      assert_equal 0, exception.reset_in
      assert_equal msg, @exception.message
    end

    def test_limit
      assert_equal 100, @exception.limit
    end

    def test_limit_with_header
      rate_limit_headers = {
        "x-rate-limit-limit" => "100"
      }
      exception = TooManyRequests.new("Rate Limit Exceeded", rate_limit_headers)

      assert_equal 100, exception.limit
    end

    def test_remaining
      assert_equal 0, @exception.remaining
    end

    def test_remaining_with_header
      rate_limit_headers = {
        "x-rate-limit-remaining" => "5"
      }
      exception = TooManyRequests.new("Rate Limit Exceeded", rate_limit_headers)

      assert_equal 5, exception.remaining
    end

    def test_reset_at
      assert_in_delta Time.now + 60, @exception.reset_at, 1
    end

    def test_reset_in
      assert_in_delta 60, @exception.reset_in, 1
    end

    def test_retry_after
      assert_in_delta 60, @exception.retry_after, 1
    end

    def test_reset_in_minimum_value
      past_timexception = Time.now - 60
      rate_limit_headers = {
        "x-rate-limit-reset" => past_timexception.to_i.to_s
      }
      exception = TooManyRequests.new("Rate Limit Exceeded", rate_limit_headers)

      assert_equal 0, exception.reset_in
    end

    def test_reset_in_ceil
      future_timexception = Time.now + 61
      rate_limit_headers = {
        "x-rate-limit-reset" => future_timexception.to_i.to_s
      }
      exception = TooManyRequests.new("Rate Limit Exceeded", rate_limit_headers)

      assert_equal 61, exception.reset_in
    end
  end
end
