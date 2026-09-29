# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error holds every problem the body of its response describes, the first of which is its problem
  class HTTPErrorProblemsTest < Minitest::Test
    cover HTTPError

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze
    URL = "http://example.com"

    def error_for(body, headers: JSON_HEADERS)
      stub_request(:get, URL).to_return(status: [400, "Bad Request"], body:, headers:)
      assert_raises(BadRequest) { Core::ResponseParser.new.parse(response: Net::HTTP.get_response(URI(URL))) }
    end

    def test_the_problems_are_every_error_the_body_names
      body = {title: "Invalid Request", errors: [{parameter: "ids", message: "First"}, "not an object", {parameter: "user.fields", message: "Second"}]}
      error = error_for(body.to_json)

      assert_equal [%w[ids First], ["user.fields", "Second"]], error.problems.map { |problem| [problem.parameter, problem.message] }
      assert_same error.problems.first, error.problem
      assert_predicate error.problems, :frozen?
    end

    def test_the_problems_are_the_body_of_a_response_that_describes_the_failure_itself
      body = {"title" => "Unauthorized", "detail" => "Unauthorized", "type" => "about:blank", "status" => 401}

      assert_equal [body], error_for(body.to_json).problems.map(&:to_h)
    end

    def test_a_body_that_describes_no_problem_has_no_problems
      assert_empty error_for('{"data": []}').problems
      assert_empty error_for("<html>Bad</html>", headers: {"Content-Type" => "text/html"}).problems
    end
  end
end
