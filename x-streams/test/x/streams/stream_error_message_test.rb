# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The message of a StreamError names the request of the stream, as an error of x-core names its request, when it is
  # given the method and URI of that request
  class StreamErrorMessageTest < Minitest::Test
    cover StreamError
    cover "X::Streams::Error#describe"

    # The problems of the line X sends before it closes a stream
    DISCONNECT_PROBLEMS = [Problem.new({"title" => "operational-disconnect"})].freeze

    def test_the_message_names_the_request_when_given_its_method_and_uri
      uri = URI("https://api.x.com/2/tweets/search/stream")
      error = StreamError.new(problems: DISCONNECT_PROBLEMS, http_method: "GET", uri:)

      assert_equal ["GET /2/tweets/search/stream: operational-disconnect", :get, uri], [error.message, error.http_method, error.uri]
      assert_equal "GET /: operational-disconnect", StreamError.new(problems: DISCONNECT_PROBLEMS, http_method: :get, uri: URI("https://api.x.com")).message
    end

    def test_the_message_names_no_request_without_its_method_and_uri
      uri = URI("https://api.x.com/2/tweets/search/stream")

      assert_equal %w[operational-disconnect operational-disconnect], [StreamError.new(problems: DISCONNECT_PROBLEMS, http_method: :get).message, StreamError.new(problems: DISCONNECT_PROBLEMS, uri:).message]
    end

    def test_a_message_given_is_the_message_in_place_of_the_problems
      uri = URI("https://api.x.com/2/tweets/search/stream")

      assert_equal "GET /2/tweets/search/stream: The stream dropped", StreamError.new("The stream dropped", problems: DISCONNECT_PROBLEMS, http_method: :get, uri:).message
    end

    def test_a_stream_error_is_raised_with_a_message_alone_as_any_exception_is
      error = assert_raises(StreamError) { raise StreamError, "The stream dropped" }

      assert_equal ["The stream dropped", [], nil, nil], [error.message, error.problems, error.http_method, error.uri]
    end

    def test_a_stream_error_is_raised_with_nothing_as_any_exception_is
      error = assert_raises(StreamError) { raise StreamError }

      assert_equal ["X::StreamError", []], [error.message, error.problems]
      assert_equal "X::StreamError", StreamError.new(http_method: :get, uri: URI("https://api.x.com/2/tweets/search/stream")).message
    end
  end
end
