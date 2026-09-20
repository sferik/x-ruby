require_relative "../../test_helper"

module X
  class HTTPErrorMessageTest < Minitest::Test
    cover HTTPError

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze

    def setup
      @response_parser = Core::ResponseParser.new
      @uri = URI("http://example.com")
    end

    def response = Net::HTTP.get_response(@uri)

    def stub_json(status: 200, body: "{}")
      stub_request(:get, @uri.to_s).to_return(status:, body:, headers: JSON_HEADERS)
    end

    def test_an_error_without_a_content_type_takes_the_status_message
      assert_equal "Bad Request", BadRequest.new(response: Net::HTTPBadRequest.new("1.1", "400", "Bad Request")).message
    end

    def test_the_error_holds_its_response_and_status
      stub_json(status: [404, "Not Found"], body: '{"title": "Not Found Error", "detail": "Could not find user"}')
      error = assert_raises(NotFound) { @response_parser.parse(response:) }

      assert_kind_of Net::HTTPNotFound, error.response
      assert_equal ["404", 404, "Not Found Error: Could not find user"], [error.code, error.status, error.message]
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

    def test_json_body_without_a_json_content_type_falls_back_to_status
      stub_request(:get, @uri.to_s)
        .to_return(status: [400, "Bad Request"], body: '{"error": "Some Error"}', headers: {"Content-Type" => "text/plain"})

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_problem_json_content_type
      stub_request(:get, @uri.to_s)
        .to_return(status: 400, body: '{"error": "problem"}', headers: {"Content-Type" => "application/problem+json"})

      assert_equal "problem", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_non_json_error_response
      stub_request(:get, @uri.to_s)
        .to_return(status: [400, "Bad Request"], body: "<html>Bad</html>", headers: {"Content-Type" => "text/html"})

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_errors_array_takes_detail_or_title_when_an_error_has_no_message
      body = {errors: [{detail: "Detail", title: "Title"}, {title: "Title only"}, {message: 1, detail: "Not a number"}]}.to_json
      stub_json(status: 400, body:)

      assert_equal "Detail, Title only, Not a number", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_errors_array_skips_errors_without_a_message
      body = {errors: [{code: 1}, "not an object", {message: "Kept"}]}.to_json
      stub_json(status: 400, body:)

      assert_equal "Kept", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_errors_array_without_messages_falls_back_to_title_and_detail
      body = {title: "Some Error", detail: "Something went wrong", errors: [{code: 1}]}.to_json
      stub_json(status: 400, body:)

      assert_equal "Some Error: Something went wrong", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_empty_errors_array_falls_back_to_error_field
      stub_json(status: 400, body: '{"errors": [], "error": "Some Error"}')

      assert_equal "Some Error", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    def test_error_field_that_is_not_a_string_falls_back_to_status
      stub_json(status: [400, "Bad Request"], body: '{"error": {"code": 1}}')

      assert_equal "Bad Request", assert_raises(BadRequest) { @response_parser.parse(response:) }.message
    end

    {"invalid JSON" => "<html>Oops</html>", "empty" => "", "array" => "[1]", "string" => '"text"'}.each do |name, body|
      define_method(:"test_#{name.tr(" ", "_")}_json_error_body_falls_back_to_status") do
        stub_json(status: [503, "Service Unavailable"], body:)

        assert_equal "Service Unavailable", assert_raises(ServiceUnavailable) { @response_parser.parse(response:) }.message
      end
    end

    def test_json_error_without_a_body_falls_back_to_status
      response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
      response["content-type"] = "application/json"
      response.instance_variable_set(:@read, true)

      assert_equal "Service Unavailable", ServiceUnavailable.new(response:).message
    end
  end
end
