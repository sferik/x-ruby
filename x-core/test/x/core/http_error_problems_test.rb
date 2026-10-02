# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error holds every problem the body of its response names, and the problem it describes the failure with
  class HTTPErrorProblemsTest < Minitest::Test
    cover HTTPError

    JSON_HEADERS = {"Content-Type" => "application/json"}.freeze
    URL = "http://example.com"

    def error_for(body, headers: JSON_HEADERS)
      stub_request(:get, URL).to_return(status: [400, "Bad Request"], body:, headers:)
      assert_raises(BadRequest) { Core.const_get(:ResponseParser).new.parse(response: Net::HTTP.get_response(URI(URL))) }
    end

    def test_the_problems_are_every_error_the_body_names
      body = {title: "Invalid Request", errors: [{parameter: "ids", message: "First"}, "not an object", {parameter: "user.fields", message: "Second"}]}
      error = error_for(body.to_json)

      assert_equal [%w[ids First], ["user.fields", "Second"]], error.problems.map { |problem| [problem.parameter, problem.message] }
      assert_predicate error.problems, :frozen?
    end

    def test_the_problem_of_a_request_the_api_refused_a_parameter_of_is_the_problem_of_the_whole_response
      error = error_for({errors: [{parameters: {ids: ["abc"]}, message: "The `ids` query parameter value [abc] is not valid"}],
                         title: "Invalid Request", detail: "One or more parameters to your request was invalid.",
                         type: "https://api.twitter.com/2/problems/invalid-request"}.to_json)

      assert_equal ["Invalid Request", "https://api.twitter.com/2/problems/invalid-request"], [error.problem.title, error.problem.type]
      assert_equal ["The `ids` query parameter value [abc] is not valid"], error.problems.map(&:message)
      assert_equal "The `ids` query parameter value [abc] is not valid", error.message
    end

    def test_the_problems_are_the_body_of_a_response_that_describes_the_failure_itself
      body = {"title" => "Unauthorized", "detail" => "Unauthorized", "type" => "about:blank", "status" => 401}
      error = error_for(body.to_json)

      assert_equal [body], error.problems.map(&:to_h)
      assert_same error.problem, error.problems.first
      assert_predicate error.problems, :frozen?
    end

    def test_a_body_that_describes_no_problem_has_no_problems
      assert_empty error_for('{"data": []}').problems
      assert_empty error_for("<html>Bad</html>", headers: {"Content-Type" => "text/html"}).problems
    end
  end
end
