# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class HTTPErrorRetryAfterTest < Minitest::Test
    cover HTTPError

    def error_for(retry_after, date: nil)
      response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
      response["retry-after"] = retry_after unless retry_after.nil?
      response["date"] = date unless date.nil?
      ServiceUnavailable.new(http_response: response)
    end

    def test_a_response_that_asks_for_no_wait_asks_for_nothing
      assert_nil error_for(nil).retry_after
    end

    # An error whose response was sent at a time on the clock of the API, and asks for a wait of 30 seconds on it
    def api_clock_error(sent) = error_for((sent + 30).httpdate, date: sent.httpdate)

    def test_the_header_counts_the_seconds_to_wait
      assert_equal 42, error_for("42").retry_after
    end

    def test_a_padded_header_counts_in_tens_rather_than_eights
      assert_equal 60, error_for("060").retry_after
    end

    def test_the_header_names_the_time_to_wait_until
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal 300, error_for((Time.now + 300).httpdate).retry_after
      end
    end

    def test_the_part_of_a_second_an_http_date_leaves_off_is_waited_out
      Time.stub :now, Time.utc(1983, 11, 24, 0, 0, 0, 900_000) do
        assert_equal 62, error_for((Time.now + 62).httpdate).retry_after
      end
    end

    def test_a_time_that_has_passed_asks_for_no_wait_rather_than_a_negative_one
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal 0, error_for((Time.now - 300).httpdate).retry_after
      end
    end

    def test_an_http_date_counts_from_the_date_the_response_was_sent_on_the_clock_of_the_api
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal [30, 30], [-3600, 3600].map { |offset| api_clock_error(Time.now + offset).retry_after }
      end
    end

    def test_an_http_date_counts_from_now_when_the_date_of_the_response_cannot_be_read
      Time.stub :now, Time.utc(1983, 11, 24) do
        assert_equal 300, error_for((Time.now + 300).httpdate, date: "yesterday").retry_after
      end
    end

    def test_a_header_that_names_no_time_asks_for_nothing
      assert_nil error_for("whenever you like").retry_after
    end
  end
end
