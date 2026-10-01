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
    cover Core.const_get(:BuiltResponse)

    URI_OF_REQUEST = URI("https://api.x.com/2/users/1?user.fields=id")
    NOT_FOUND = {status: 404, headers: {"content-type" => "application/json"},
                 body: '{"title":"Not Found Error","detail":"Could not find user."}'}.freeze

    def not_found = NotFound.new(**NOT_FOUND).http_response

    def test_an_http_error_is_built_from_a_response
      error = NotFound.new(http_response: not_found)

      assert_equal [404, "Not Found Error"], [error.status, error.problem.title]
    end

    def test_an_http_error_names_the_request_it_is_given
      error = NotFound.new(http_response: not_found, http_method: :get, uri: URI_OF_REQUEST)

      assert_equal [:get, URI_OF_REQUEST], [error.http_method, error.uri]
      assert_equal "GET /2/users/1: Not Found Error: Could not find user.", error.message
    end

    def test_the_errors_of_a_request_are_built_with_a_message
      [NetworkError, TooManyRedirects].each do |error_class|
        error = error_class.new("went wrong", http_method: :get, uri: URI_OF_REQUEST)

        assert_equal [:get, URI_OF_REQUEST, "GET /2/users/1: went wrong"], [error.http_method, error.uri, error.message]
      end
    end

    def test_the_errors_of_a_line_of_a_stream_name_the_request_of_the_stream
      problems = [Problem.new({"title" => "operational-disconnect"})]

      assert_equal "GET /2/users/1: operational-disconnect", StreamError.new(problems, http_method: :get, uri: URI_OF_REQUEST).message
      assert_equal [:get, URI_OF_REQUEST], InvalidResponse.new(http_response: not_found, body: "<", http_method: :get, uri: URI_OF_REQUEST).then { |error| [error.http_method, error.uri] }
    end

    def test_an_invalid_response_is_built_from_a_response_and_the_body_that_is_not_json
      error = InvalidResponse.new(http_response: not_found, body: "<html>")

      assert_equal [404, "<html>", NOT_FOUND[:body]], [error.status, error.body, error.http_response.body]
    end

    def test_the_errors_of_problems_are_built_from_problems
      problems = [Problem.new({"title" => "Invalid Rule", "detail" => "Too long"})]

      assert_equal problems, StreamError.new(problems).problems
      assert_equal [problems, 0], RulesRejected.new(problems, result: 0).then { |error| [error.problems, error.result] }
    end

    def test_a_response_is_built_from_a_response
      response = Response.new(http_response: not_found, http_method: :get, uri: URI("https://api.x.com/2/users/1"))

      assert_equal [:get, 404, NOT_FOUND[:body]], [response.http_method, response.status, response.body]
    end

    def test_a_response_summarizes_the_part_of_the_body_it_is_given
      response = Response.new(http_response: not_found, http_method: :get, uri: URI_OF_REQUEST, body: "{}")

      assert_equal ["{}", NOT_FOUND[:body]], [response.body, response.http_response.body]
    end

    def test_a_rate_limit_is_built_only_from_a_response
      assert_raises(NoMethodError) { RateLimit.new(type: RateLimit::RATE_LIMIT_TYPE, http_response: not_found) }
    end
  end
end
