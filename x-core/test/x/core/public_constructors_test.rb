# frozen_string_literal: true

require "net/http"
require_relative "../../test_helper"

module X
  # The errors x-core raises, and the summary an on_response hook is passed, can be built by hand, so that code that
  # rescues one, or a hook, can be tested, while a rate limit is built only from a response
  class PublicConstructorsTest < Minitest::Test
    cover HTTPError
    cover NetworkError
    cover InvalidResponse
    cover StreamError
    cover TooManyRedirects
    cover RulesRejected
    cover Response
    cover RateLimit

    def not_found
      Net::HTTPNotFound.new("1.1", "404", "Not Found").tap do |response|
        response["content-type"] = "application/json"
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, '{"title":"Not Found Error","detail":"Could not find user."}')
      end
    end

    def request = Net::HTTP::Get.new(URI("https://api.x.com/2/users/1"))

    def test_an_http_error_is_built_from_a_response
      error = NotFound.new(http_response: not_found)

      assert_equal [404, "Not Found Error"], [error.status, error.problem.title]
      assert_raises(NotFound) { raise error }
    end

    def test_an_http_error_names_the_request_it_is_given
      error = NotFound.new(http_response: not_found, request:)

      assert_equal [:get, URI("https://api.x.com/2/users/1")], [error.http_method, error.uri]
    end

    def test_the_errors_of_a_request_are_built_with_a_message
      [NetworkError, TooManyRedirects].each do |error_class|
        error = error_class.new("went wrong", request:)

        assert_equal [:get, URI("https://api.x.com/2/users/1")], [error.http_method, error.uri]
        assert_includes error.message, "went wrong"
      end
    end

    def test_an_invalid_response_is_built_from_a_response
      error = InvalidResponse.new(http_response: not_found, body: "<html>")

      assert_equal [404, "<html>"], [error.status, error.body]
    end

    def test_the_errors_of_problems_are_built_from_problems
      problems = [Problem.new({"title" => "Invalid Rule", "detail" => "Too long"})]

      assert_equal problems, StreamError.new(problems).problems
      assert_equal [problems, 0], RulesRejected.new(problems, result: 0).then { |error| [error.problems, error.result] }
    end

    def test_a_response_is_built_from_a_response
      response = Response.new(:get, URI("https://api.x.com/2/users/1"), not_found)

      assert_equal [:get, 404], [response.http_method, response.status]
    end

    def test_a_rate_limit_is_built_only_from_a_response
      assert_raises(NoMethodError) { RateLimit.new(type: RateLimit::RATE_LIMIT_TYPE, http_response: not_found) }
    end
  end
end
