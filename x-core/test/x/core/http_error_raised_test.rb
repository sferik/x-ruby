# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An HTTP error of a status is raised as any other exception is, with or without a message, as a test double that
  # stands in for a client raises one
  class HTTPErrorRaisedTest < Minitest::Test
    cover HTTPError
    cover InvalidResponse

    STATUSES = {BadRequest => 400, Unauthorized => 401, PaymentRequired => 402, Forbidden => 403, NotFound => 404,
                MethodNotAllowed => 405, NotAcceptable => 406, RequestTimeout => 408, Conflict => 409, Gone => 410,
                PayloadTooLarge => 413, UnsupportedMediaType => 415, UnprocessableEntity => 422, TooManyRequests => 429,
                UnavailableForLegalReasons => 451, InternalServerError => 500, BadGateway => 502,
                ServiceUnavailable => 503, GatewayTimeout => 504, ClientError => 400, ServerError => 500,
                InvalidResponse => 200}.freeze

    def test_an_error_of_a_status_is_raised_without_arguments
      error = assert_raises(NotFound) { raise NotFound }

      assert_equal [404, "Not Found", nil], [error.status, error.message, error.body]
    end

    def test_an_error_of_a_status_is_raised_with_a_message
      error = assert_raises(TooManyRequests) { raise TooManyRequests, "slow down" }

      assert_equal [429, "slow down"], [error.status, error.message]
    end

    def test_each_error_of_a_status_is_built_with_its_status
      assert_equal STATUSES, STATUSES.to_h { |error_class, _| [error_class, error_class.new.status] }
    end

    def test_an_error_that_descends_from_one_of_a_status_is_built_with_its_status
      assert_equal 404, Class.new(NotFound).new.status
      assert_equal 400, Class.new(ClientError).new.status
      assert_equal 200, Class.new(InvalidResponse).new.status
    end

    def test_a_message_takes_the_place_of_the_one_the_body_describes
      error = NotFound.new("gone", status: 404, headers: {"content-type" => "application/json"}, body: '{"title":"Not Found Error"}')

      assert_equal ["gone", "Not Found Error"], [error.message, error.problem.title]
    end

    def test_a_message_names_the_request
      error = NotFound.new("gone", http_method: :get, uri: URI("https://api.x.com/2/users/1"))

      assert_equal "GET /2/users/1: gone", error.message
    end

    def test_a_status_given_is_the_status_of_the_error
      assert_equal 418, ClientError.new(status: 418).status
    end

    def test_an_invalid_response_is_raised_with_a_message
      error = assert_raises(InvalidResponse) { raise InvalidResponse, "not JSON" }

      assert_equal [200, "not JSON", nil], [error.status, error.message, error.body]
    end

    def test_an_http_error_itself_must_be_given_a_status
      assert_raises(ArgumentError) { raise HTTPError }
      assert_raises(ArgumentError) { HTTPError.new("failed") }
    end
  end
end
