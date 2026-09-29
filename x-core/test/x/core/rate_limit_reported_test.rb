# frozen_string_literal: true

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
      error = TooManyRequests.new(http_response: response(FULL.except("x-rate-limit-reset")))

      assert_empty error.rate_limits
      assert_nil error.rate_limit
      assert_nil error.retry_after
    end

    def test_all_from_reads_every_limit_a_response_reports_in_the_order_of_the_types
      http_response = response(FULL.merge("x-user-limit-24hour-limit" => "25", "x-user-limit-24hour-remaining" => "5",
        "x-user-limit-24hour-reset" => "2"))

      assert_equal [["rate-limit", 0], ["user-limit-24hour", 5]],
        RateLimit.all_from(http_response).map { |limit| [limit.type, limit.remaining] }
    end

    def test_a_summary_leaves_out_a_limit_without_every_header
      http_response = response(FULL.except("x-rate-limit-limit"))

      assert_empty Response.new(:get, URI("https://api.x.com/2/users/me"), http_response).rate_limits
    end

    def test_a_rate_limit_is_read_in_base_10
      limit = RateLimit.all_from(response("x-rate-limit-limit" => "050", "x-rate-limit-remaining" => "010", "x-rate-limit-reset" => "0100")).first

      assert_equal [50, 10, Time.at(100)], [limit.limit, limit.remaining, limit.reset_at]
    end

    def test_a_rate_limit_whose_header_is_not_a_count_in_base_10_is_not_reported
      FULL.each_key do |header|
        ["0x10", "1e3", "-1", "", "later", "1\n2"].each do |value|
          refute RateLimit.reported?("rate-limit", FULL.merge(header => value)), "#{header}: #{value.inspect}"
        end
      end
    end

    def test_a_refusal_whose_reset_is_not_a_count_says_nothing_of_when_to_retry
      error = TooManyRequests.new(http_response: response(FULL.merge("x-rate-limit-reset" => "soon")))

      assert_empty error.rate_limits
      assert_nil error.retry_after
    end

    def test_a_refusal_whose_reset_is_not_a_count_raises_itself_from_a_request
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 429, headers: FULL.merge("x-rate-limit-reset" => "soon"))
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1, max_rate_limit_wait: 0)

      assert_raises(TooManyRequests) { client.get("users/me") }
    end

    private

    def response(headers)
      Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests").tap do |http_response|
        headers.each { |name, value| http_response[name] = value }
      end
    end
  end
end
