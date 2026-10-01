# frozen_string_literal: true

require "net/http"
require_relative "../../test_helper"

module X
  # The errors of a response, and the summary of one, are built by hand from its status, headers, and body, of which
  # x-core builds the Net::HTTP response they hold, so that a test need not build one
  class PublicConstructorsBuiltTest < Minitest::Test
    cover HTTPError
    cover InvalidResponse
    cover Response
    cover Core.const_get(:BuiltResponse)

    URI_OF_REQUEST = URI("https://api.x.com/2/users/1?user.fields=id")
    NOT_FOUND = {status: 404, headers: {"content-type" => "application/json"},
                 body: '{"title":"Not Found Error","detail":"Could not find user."}'}.freeze

    def not_found = NotFound.new(**NOT_FOUND).http_response

    def test_an_http_error_is_built_from_a_status_headers_and_body
      error = NotFound.new(**NOT_FOUND)

      assert_equal [404, "Not Found Error", NOT_FOUND[:body]], [error.status, error.problem.title, error.body]
      assert_equal({"content-type" => "application/json"}, error.headers)
      assert_equal "Not Found Error: Could not find user.", error.message
      assert_raises(NotFound) { raise error }
    end

    def test_an_http_error_built_from_a_status_alone_is_named_by_its_reason_phrase
      error = TooManyRequests.new(status: 429)

      assert_kind_of Net::HTTPTooManyRequests, error.http_response
      assert_equal ["1.1", "429"], [error.http_response.http_version, error.http_response.code]
      assert_equal ["Too Many Requests", nil, {}], [error.message, error.body, error.headers]
    end

    def test_a_status_net_http_names_no_class_of_is_built_as_one_of_its_class_of_statuses
      error = ClientError.new(status: 418)

      assert_kind_of Net::HTTPClientError, error.http_response
      assert_equal [418, "Client Error"], [error.status, error.message]
    end

    def test_a_status_named_by_initials_is_read_apart_from_its_words
      assert_equal "URI Too Long", ClientError.new(status: 414).message
    end

    def test_the_body_of_a_response_built_is_tagged_utf8_without_changing_the_body_given
      body = (+"caf\xC3\xA9").force_encoding(Encoding::BINARY)
      error = HTTPError.new(status: 500, body:)

      assert_equal [Encoding::UTF_8, "café"], [error.body.encoding, error.body]
      assert_equal Encoding::BINARY, body.encoding
    end

    def test_a_response_and_a_status_are_refused_together
      error = assert_raises(ArgumentError) { HTTPError.new(http_response: not_found, status: 404) }

      assert_equal "Pass the http_response:, or the status:, headers:, and body: one is built of, and not both", error.message
    end

    def test_a_response_is_refused_beside_headers_or_a_body
      assert_raises(ArgumentError) { HTTPError.new(http_response: not_found, headers: {}) }
      assert_raises(ArgumentError) { HTTPError.new(http_response: not_found, body: "{}") }
    end

    def test_an_error_is_refused_without_a_response_or_a_status
      error = assert_raises(ArgumentError) { HTTPError.new }

      assert_equal "Pass the http_response:, or the status:, headers:, and body: one is built of, and not both", error.message
      assert_raises(ArgumentError) { HTTPError.new(headers: {}, body: "{}") }
    end

    def test_a_status_http_does_not_define_is_refused
      [99, 600, "404", 404.0].each do |status|
        error = assert_raises(ArgumentError) { HTTPError.new(status:) }

        assert_equal "status must be an Integer from 100 to 599, not #{status.inspect}", error.message
      end
      assert_equal [100, 599], [Response.new(http_method: :get, uri: URI_OF_REQUEST, status: 100).status, ServerError.new(status: 599).status]
    end

    def test_headers_are_named_in_any_case_by_a_string_or_a_symbol
      assert_equal({"content-type" => "application/json"}, HTTPError.new(status: 404, headers: {"Content-Type": "application/json"}).headers)
    end

    def test_headers_that_are_not_a_hash_of_names_to_values_are_refused
      assert_raises(ArgumentError) { HTTPError.new(status: 404, headers: [["content-type", "text/html"]]) }
      assert_raises(ArgumentError) { HTTPError.new(status: 404, headers: {"retry-after" => 60}) }
    end

    def test_an_invalid_response_is_built_from_a_status_headers_and_body
      error = InvalidResponse.new(status: 200, headers: {"content-type" => "text/html"}, body: "<html>")

      assert_equal [200, "<html>", "<html>"], [error.status, error.body, error.http_response.body]
      assert_equal "The body of the 200 response is not JSON (text/html)", error.message
    end

    def test_an_invalid_response_is_refused_a_response_beside_a_status_or_headers
      assert_raises(ArgumentError) { InvalidResponse.new(http_response: not_found, status: 404) }
      assert_raises(ArgumentError) { InvalidResponse.new(http_response: not_found, headers: {}) }
    end

    def test_a_response_is_built_from_a_status_headers_and_body
      response = Response.new(http_method: :get, uri: URI_OF_REQUEST, status: 200,
        headers: {"x-rate-limit-limit" => "75", "x-rate-limit-remaining" => "74", "x-rate-limit-reset" => "1700000000"},
        body: '{"data":{"id":"1"}}')

      assert_predicate response, :success?
      assert_equal [200, '{"data":{"id":"1"}}', 74], [response.status, response.http_response.body, response.rate_limits.first.remaining]
    end

    def test_a_response_is_refused_a_response_beside_a_status_or_headers
      assert_raises(ArgumentError) { Response.new(http_response: not_found, http_method: :get, uri: URI_OF_REQUEST, status: 404) }
      assert_raises(ArgumentError) { Response.new(http_response: not_found, http_method: :get, uri: URI_OF_REQUEST, headers: {}) }
      assert_raises(ArgumentError) { Response.new(http_method: :get, uri: URI_OF_REQUEST) }
    end
  end
end
