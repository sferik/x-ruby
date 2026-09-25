# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class InvalidResponseTest < Minitest::Test
    cover InvalidResponse

    def setup
      @response = Net::HTTPOK.new("1.1", "200", "OK")
      @response["content-type"] = "text/html"
    end

    def test_the_error_holds_the_response_and_the_body_it_is_given
      error = InvalidResponse.new(http_response: @response, body: "<html>")

      assert_same @response, error.http_response
      assert_equal "<html>", error.body
      assert_equal "The body of the 200 response is not JSON (text/html)", error.message
    end

    def test_the_error_reads_the_status_as_an_integer
      assert_equal 200, InvalidResponse.new(http_response: @response).status
    end

    def test_the_error_reads_the_headers_by_lowercase_name_and_joins_a_repeated_one
      @response.add_field("X-Cache", "MISS")
      @response.add_field("X-Cache", "HIT")
      headers = InvalidResponse.new(http_response: @response).headers

      assert_equal({"content-type" => "text/html", "x-cache" => "MISS, HIT"}, headers)
      assert_predicate headers, :frozen?
    end

    def test_an_error_without_a_body_never_reads_the_body_of_the_response
      @response.define_singleton_method(:body) { raise IOError, "attempt to read body out of block" }

      assert_nil InvalidResponse.new(http_response: @response).body
    end

    def test_the_message_names_a_response_without_a_content_type
      @response.delete("content-type")

      assert_equal "The body of the 200 response is not JSON (no content type)", InvalidResponse.new(http_response: @response).message
    end
  end
end
