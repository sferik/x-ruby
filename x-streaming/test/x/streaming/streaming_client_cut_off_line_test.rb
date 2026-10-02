# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream the server ends within a line ends as a dropped stream does: the line it was cut off within is neither
  # parsed, which would raise InvalidResponse and back off as from a server error, nor passed to on_response
  class StreamingClientCutOffLineTest < Minitest::Test
    cover Streaming.const_get(:StreamParser)
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      stub_request(:get, STREAM_URL).to_return({body: "{\"data\":{\"id\":\"1\"}}\r\n{\"data\":{\"id\""}, {body: "{\"data\":{\"id\""})
      @responses = []
      @sleeps = []
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(response) { @responses << response.body }).streaming(max_reconnects: 2)
    end

    def test_a_stream_the_server_ends_within_a_line_raises_that_the_stream_ended
      posts = []
      error = assert_raises(NetworkError) { without_sleeping { @streaming_client.stream("tweets/sample/stream") { |post| posts << post } } }

      assert_equal "GET /2/tweets/sample/stream: The stream ended", error.message
      assert_equal [{"data" => {"id" => "1"}}], posts
    end

    def test_a_stream_the_server_ends_within_a_line_reconnects_as_a_dropped_stream_does
      assert_raises(NetworkError) { without_sleeping { @streaming_client.stream("tweets/sample/stream") { |post| post } } }

      assert_equal [0.0, 0.25], @sleeps
      assert_requested(:get, STREAM_URL, times: 3)
    end

    def test_the_line_a_stream_was_cut_off_within_is_not_passed_to_on_response
      assert_raises(NetworkError) { without_sleeping { @streaming_client.stream("tweets/sample/stream") { |post| post } } }

      assert_equal ["{\"data\":{\"id\":\"1\"}}"], @responses
    end

    private

    def without_sleeping(&)
      @streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(seconds) { @sleeps << seconds }, &)
    end
  end
end
