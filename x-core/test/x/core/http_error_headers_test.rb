# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class HTTPErrorHeadersTest < Minitest::Test
    cover HTTPError
    cover Core::ResponseHeaders

    URL = "https://api.x.com/2/users/me"

    def test_the_headers_are_read_by_lowercase_name
      error = error_for("Content-Type" => "application/json", "X-Rate-Limit-Remaining" => "0")

      assert_equal({"content-type" => "application/json", "x-rate-limit-remaining" => "0"}, error.headers)
    end

    def test_a_header_sent_more_than_once_is_joined_with_a_comma
      error = error_for({})
      error.http_response.add_field("x-label", "one")
      error.http_response.add_field("x-label", "two")

      assert_equal "one, two", error.headers["x-label"]
    end

    def test_the_headers_are_frozen_and_a_response_without_any_has_none
      error = error_for({})

      assert_predicate error.headers, :frozen?
      assert_empty TooManyRequests.new(http_response: Net::HTTPTooManyRequests.new("1.1", "429", "")).headers
    end

    private

    # The error of a response the API refused with the given headers
    def error_for(headers)
      stub_request(:get, URL).to_return(status: 429, headers:)
      assert_raises(TooManyRequests) { Client.new.get("users/me") }
    end
  end
end
