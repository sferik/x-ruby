require_relative "../test_helper"

module X
  class TooManyRequestsTest < Minitest::Test
    cover TooManyRequests

    def setup
      Time.stub :now, Time.utc(1983, 11, 24) do
        response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
        response["x-rate-limit-limit"] = "100"
        response["x-rate-limit-remaining"] = "0"
        response["x-rate-limit-reset"] = (Time.now + 60).to_i.to_s
        @exception = TooManyRequests.new(response: response)
      end
    end

    def test_initialize_with_empty_response
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      exception = TooManyRequests.new(response: response)

      assert_equal 0, exception.limit
      assert_equal 0, exception.remaining
      assert_equal Time.at(0).utc, exception.reset_at
      assert_equal 0, exception.reset_in
      assert_equal "Too Many Requests", @exception.message
    end

    def test_limit
      assert_equal 100, @exception.limit
    end

    def test_limit_with_header
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      response["x-rate-limit-limit"] = "100"
      exception = TooManyRequests.new(response: response)

      assert_equal 100, exception.limit
    end

    def test_remaining
      assert_equal 0, @exception.remaining
    end

    def test_remaining_with_header
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      response["x-rate-limit-remaining"] = "5"
      exception = TooManyRequests.new(response: response)

      assert_equal 5, exception.remaining
    end

    def test_reset_at
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal Time.now + 60, @exception.reset_at
      end
    end

    def test_reset_in
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal 60, @exception.reset_in
      end
    end

    def test_retry_after
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal 60, @exception.retry_after
      end
    end

    def test_reset_in_minimum_value
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      response["x-rate-limit-reset"] = (Time.now - 60).to_i.to_s
      exception = TooManyRequests.new(response: response)

      assert_equal 0, exception.reset_in
    end

    def test_reset_in_ceil
      response = Net::HTTPTooManyRequests.new("1.1", 429, "Too Many Requests")
      response["x-rate-limit-reset"] = (Time.now + 61).to_i.to_s
      exception = TooManyRequests.new(response: response)

      assert_equal 61, exception.reset_in
    end
  end
end
