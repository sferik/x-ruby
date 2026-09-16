require_relative "../../test_helper"

module X
  class RateLimitReportedTest < Minitest::Test
    cover RateLimit
    cover TooManyRequests
    cover Response

    FULL = {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => "1"}.freeze

    def test_a_rate_limit_is_reported_only_with_all_three_headers
      assert RateLimit.reported?("rate-limit", FULL)
      FULL.each_key { |header| refute RateLimit.reported?("rate-limit", FULL.except(header)) }
      refute RateLimit.reported?("app-limit-24hour", FULL)
    end

    def test_an_exhausted_limit_without_a_reset_time_is_left_out
      error = TooManyRequests.new(response: response(FULL.except("x-rate-limit-reset")))

      assert_empty error.rate_limits
      assert_nil error.rate_limit
      assert_equal 0, error.retry_after
    end

    def test_a_summary_leaves_out_a_limit_without_every_header
      http_response = response(FULL.except("x-rate-limit-limit"))

      assert_empty Response.new(:get, URI("https://api.x.com/2/users/me"), http_response).rate_limits
    end

    private

    def response(headers)
      Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests").tap do |http_response|
        headers.each { |name, value| http_response[name] = value }
      end
    end
  end
end
