# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The message of a StreamError names the request of the stream, as an error of x-core names its request, when it is
  # given the method and URI of that request
  class StreamErrorMessageTest < Minitest::Test
    cover StreamError

    # The problems of the line X sends before it closes a stream
    DISCONNECT_PROBLEMS = [Problem.new({"title" => "operational-disconnect"})].freeze

    def test_the_message_names_the_request_when_given_its_method_and_uri
      uri = URI("https://api.x.com/2/tweets/search/stream")
      error = StreamError.new(DISCONNECT_PROBLEMS, http_method: "GET", uri:)

      assert_equal ["GET /2/tweets/search/stream: operational-disconnect", :get, uri], [error.message, error.http_method, error.uri]
      assert_equal "GET /: operational-disconnect", StreamError.new(DISCONNECT_PROBLEMS, http_method: :get, uri: URI("https://api.x.com")).message
    end

    def test_the_message_names_no_request_without_its_method_and_uri
      uri = URI("https://api.x.com/2/tweets/search/stream")

      assert_equal %w[operational-disconnect operational-disconnect], [StreamError.new(DISCONNECT_PROBLEMS, http_method: :get).message, StreamError.new(DISCONNECT_PROBLEMS, uri:).message]
    end
  end
end
