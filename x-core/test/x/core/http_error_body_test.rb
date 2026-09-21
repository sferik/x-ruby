# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class HTTPErrorBodyTest < Minitest::Test
    cover HTTPError

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze
    HTML_HEADERS = {"Content-Type" => "text/html"}.freeze

    def setup
      @response_parser = Core::ResponseParser.new
      @uri = URI("http://example.com")
    end

    def response = Net::HTTP.get_response(@uri)

    def error_for(body, headers: JSON_HEADERS)
      stub_request(:get, @uri.to_s).to_return(status: [400, "Bad Request"], body:, headers:)
      assert_raises(BadRequest) { @response_parser.parse(response:) }
    end

    def test_the_body_is_the_json_the_api_sent
      body = '{"title": "Invalid Request", "detail": "One or more parameters are invalid"}'

      assert_equal body, error_for(body).body
    end

    def test_the_body_is_whatever_was_sent_in_place_of_json
      assert_equal "<html>Bad</html>", error_for("<html>Bad</html>", headers: HTML_HEADERS).body
    end

    def test_a_response_without_a_body_has_none
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      response.instance_variable_set(:@read, true)

      assert_nil BadRequest.new(response:).body
    end

    def test_the_problem_is_the_first_error_the_body_names
      body = {title: "Invalid Request", errors: [{parameters: {ids: ["abc"]}, message: "The ids query parameter is invalid"}, {message: "Second"}]}
      problem = error_for(body.to_json).problem

      assert_equal "The ids query parameter is invalid", problem["message"]
      assert_equal({"ids" => ["abc"]}, problem["parameters"])
    end

    def test_the_problem_is_the_body_of_a_response_that_describes_the_failure_itself
      body = {type: "https://api.x.com/2/problems/invalid-request", title: "Invalid Request", detail: "One or more parameters are invalid"}

      assert_equal JSON.parse(body.to_json), error_for(body.to_json).problem
    end

    def test_each_key_that_describes_a_failure_makes_the_body_the_problem
      %w[title detail type error].each { |key| assert_equal({key => "value"}, error_for({key => "value"}.to_json).problem) }
    end

    def test_an_errors_field_that_is_not_an_array_falls_back_to_the_problem_the_body_describes
      body = '{"errors": {"message": "Some Error"}, "detail": "One or more parameters are invalid"}'

      assert_equal JSON.parse(body), error_for(body).problem
    end

    def test_an_errors_array_of_anything_but_objects_falls_back_to_the_problem_the_body_describes
      body = '{"errors": ["not an object"], "detail": "One or more parameters are invalid"}'

      assert_equal JSON.parse(body), error_for(body).problem
    end

    def test_the_problem_is_frozen
      assert_predicate error_for('{"error": "Some Error"}').problem, :frozen?
    end

    def test_a_body_that_describes_no_problem_has_none
      assert_nil error_for('{"data": []}').problem
    end

    def test_a_body_that_is_not_json_describes_no_problem
      assert_nil error_for("<html>Bad</html>", headers: HTML_HEADERS).problem
    end
  end
end
