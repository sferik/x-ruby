# frozen_string_literal: true

require "ostruct"
require_relative "../../test_helper"

module X
  class ResponseParserTest < Minitest::Test
    cover Core::ResponseParser

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

    def setup
      @response_parser = Core::ResponseParser.new
      @uri = URI("http://example.com")
    end

    def response = Net::HTTP.get_response(@uri)

    def stub_json(status: 200, body: "{}")
      stub_request(:get, @uri.to_s).to_return(status:, body:, headers: JSON_HEADERS)
    end

    def test_success_response
      stub_json(body: '{"message": "success"}')

      assert_equal({"message" => "success"}, @response_parser.parse(response:))
    end

    def test_non_json_success_response
      stub_request(:get, @uri.to_s).to_return(body: "<html></html>", headers: {"Content-Type" => "text/html"})
      error = assert_raises(InvalidResponse) { @response_parser.parse(response:) }

      assert_equal "The body of the 200 response is not JSON (text/html)", error.message
      assert_equal ["<html></html>", "<html></html>"], [error.body, error.response.body]
      assert_kind_of JSON::ParserError, error.cause
    end

    def test_non_json_success_response_without_a_content_type
      stub_request(:get, @uri.to_s).to_return(status: 201, body: "Created")

      assert_equal "The body of the 201 response is not JSON (no content type)",
        assert_raises(InvalidResponse) { @response_parser.parse(response:) }.message
    end

    def test_empty_success_response
      stub_request(:get, @uri.to_s).to_return(status: 200, body: " \r\n")

      assert_nil @response_parser.parse(response:)
    end

    def test_success_response_without_a_body
      stub_request(:get, @uri.to_s).to_return(status: 202)

      assert_nil @response_parser.parse(response:)
    end

    def test_204_no_content_response
      stub_request(:get, @uri.to_s).to_return(status: 204)

      assert_nil @response_parser.parse(response:)
    end

    def test_bad_request_error
      stub_request(:get, @uri.to_s).to_return(status: 400)
      exception = assert_raises(BadRequest) { @response_parser.parse(response:) }

      assert_kind_of Net::HTTPBadRequest, exception.response
      assert_equal 400, exception.status
    end

    def test_unknown_error_code
      stub_request(:get, @uri.to_s).to_return(status: 418)

      assert_raises(Error) { @response_parser.parse(response:) }
    end

    {405 => ClientError, 499 => ClientError, 501 => ServerError, 520 => ServerError, 599 => ServerError, 304 => HTTPError}.each do |status, error_class|
      define_method(:"test_unmapped_#{status}_raises_#{error_class.name.split("::").last.downcase}") do
        stub_request(:get, @uri.to_s).to_return(status:)
        exception = assert_raises(HTTPError) { @response_parser.parse(response:) }

        assert_instance_of error_class, exception
      end
    end

    def test_too_many_requests_with_headers
      stub_request(:get, @uri.to_s).to_return(status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => "1"})
      exception = assert_raises(TooManyRequests) { @response_parser.parse(response:) }

      assert_predicate exception.rate_limits.first.remaining, :zero?
    end

    def test_default_response_objects
      stub_json(body: '{"array": [1, 2, 2, 3]}')
      hash = @response_parser.parse(response:)

      assert_kind_of Hash, hash
      assert_equal [1, 2, 2, 3], hash["array"]
    end

    def test_custom_response_objects
      stub_json(body: '{"set": [1, 2, 2, 3]}')
      ostruct = @response_parser.parse(response:, object_class: OpenStruct, array_class: Set)

      assert_kind_of OpenStruct, ostruct
      assert_equal Set.new([1, 2, 3]), ostruct.set
    end
  end
end
