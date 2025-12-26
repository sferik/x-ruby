require "ostruct"
require_relative "../test_helper"

module X
  class ResponseParserTest < Minitest::Test
    cover ResponseParser

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

    def setup
      @response_parser = ResponseParser.new
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
      assert_equal "400", exception.code
    end

    def test_unknown_error_code
      stub_request(:get, @uri.to_s).to_return(status: 418)

      assert_raises(Error) { @response_parser.parse(response:) }
    end

    def test_too_many_requests_with_headers
      stub_request(:get, @uri.to_s).to_return(status: 429, headers: {"x-rate-limit-remaining" => "0"})
      exception = assert_raises(TooManyRequests) { @response_parser.parse(response:) }

      assert_predicate exception.rate_limits.first.remaining, :zero?
    end

    def test_error_with_title_only_falls_back_to_status
      stub_json(status: [400, "Bad Request"], body: '{"title": "Some Error"}')

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_with_detail_only_falls_back_to_status
      stub_json(status: [400, "Bad Request"], body: '{"detail": "Something went wrong"}')

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_with_title_and_detail
      stub_json(status: 400, body: '{"title": "Some Error", "detail": "Something went wrong"}')

      assert_equal "Some Error: Something went wrong",
        assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_with_error_field
      stub_json(status: 400, body: '{"error": "Some Error"}')

      assert_equal "Some Error", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_with_errors_array
      stub_json(status: 400, body: '{"errors": [{"message": "Error 1"}, {"message": "Error 2"}]}')

      assert_equal "Error 1, Error 2", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_errors_array_takes_priority_over_title_and_detail
      body = {title: "Generic", detail: "Details", errors: [{message: "Specific error"}]}.to_json
      stub_json(status: 400, body:)

      assert_equal "Specific error", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_with_non_array_errors_field
      stub_json(status: 400, body: '{"errors": {"message": "Some Error"}}')

      assert_empty assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_non_json_error_response
      stub_request(:get, @uri.to_s)
        .to_return(status: [400, "Bad Request"], body: "<html>Bad</html>", headers: {"Content-Type" => "text/html"})

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
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
