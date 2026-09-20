# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

# A class that fails to build an object from a response, with an error a dropped connection would raise
class FailedResponseBuilder
  def self.from_response(*, **) = raise IOError, "the builder could not read"
end

module X
  class StreamingClientCallbackTest < Minitest::Test
    cover Connection
    cover Core::StreamParser
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @refused = ->(_response) { raise Errno::ECONNREFUSED }
    end

    def test_an_on_response_hook_that_raises_stops_the_stream_rather_than_reconnect_it
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: @refused)

      assert_raises(Errno::ECONNREFUSED) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_on_response_hook_that_raises_for_a_failed_response_stops_the_stream
      stub_request(:get, STREAM_URL).to_return(status: 503)
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: @refused)

      assert_raises(Errno::ECONNREFUSED) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_object_class_that_raises_stops_the_stream_rather_than_reconnect_it
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)

      assert_raises(IOError) { client.streaming.stream("tweets/sample/stream", object_class: FailedResponseBuilder) { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_a_line_that_is_not_json_still_reconnects
      stub_request(:get, STREAM_URL).to_return({body: "<html>\r\n"},
        {status: 401, body: "{}", headers: {"Content-Type" => "application/json"}})
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming(max_reconnects: 1)

      assert_raises(Unauthorized) { without_sleeping(streaming_client) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } } }
      assert_requested(:get, STREAM_URL, times: 2)
    end

    private

    # Stream without waiting for the backoff between reconnects
    def without_sleeping(streaming_client, &)
      streaming_client.instance_variable_get(:@reconnect_handler).stub(:sleep, ->(_seconds) {}, &)
    end
  end
end
