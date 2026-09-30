# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

# A class that fails to build an object from a response, with an error a dropped connection would raise
class FailedResponseBuilder
  def self.from_response(*, **) = raise IOError, "the builder could not read"
end

module X
  class StreamingClientCallbackTest < Minitest::Test
    cover Core::Connection
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

    def test_a_stop_iteration_from_an_on_response_hook_reaches_the_caller
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { [].each.next })

      assert_raises(StopIteration) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_a_stop_iteration_from_an_object_class_reaches_the_caller
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      builder = Class.new { def self.from_response(*, **) = [].each.next }

      assert_raises(StopIteration) { Client.new(bearer_token: TEST_BEARER_TOKEN).streaming.stream("tweets/sample/stream", object_class: builder) { |_post| flunk "unexpected yield" } }
    end

    def test_an_object_class_that_raises_stops_the_stream_rather_than_reconnect_it
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)

      assert_raises(IOError) { client.streaming.stream("tweets/sample/stream", object_class: FailedResponseBuilder) { |_post| flunk "unexpected yield" } }
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_error_of_the_api_an_on_response_hook_raises_stops_the_stream_rather_than_reconnect_it
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      unavailable = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { raise unavailable }).streaming(max_reconnects: 3)
      error = without_sleeping(streaming_client) do
        assert_raises(ServiceUnavailable) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      end

      assert_same unavailable, error
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_an_unauthorized_an_object_class_raises_refreshes_no_token
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      builder = Class.new do
        def self.from_response(*, **)
          response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap { |rejected| rejected.uri = URI("https://api.x.com/2/users/me") }
          raise Unauthorized.new(http_response: response)
        end
      end
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: TEST_BEARER_TOKEN)

      assert_raises(Unauthorized) { client.streaming.stream("tweets/sample/stream", object_class: builder) { |_post| flunk "unexpected yield" } }
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
