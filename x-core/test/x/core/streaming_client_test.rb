require "json"
require_relative "../../test_helper"

module X
  class StreamingClientTest < Minitest::Test
    include StreamHelpers

    cover StreamingClient

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_yields_json_objects
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream")
      end

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_with_headers
      mock_response = mock_streaming_response(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"])
      headers = {"User-Agent" => "Custom Agent"}
      request = with_stream_request(mock_response) do
        stream_and_collect("tweets/search/stream", headers:)
      end

      assert_equal "Custom Agent", request["User-Agent"]
    end

    def test_with_custom_object_class
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream", object_class: OpenStruct)
      end

      assert_kind_of OpenStruct, results[0]
    end

    def test_with_custom_array_class
      results = with_stubbed_stream(chunks: ["{\"ids\":[1,2,2,3]}\r\n"]) do
        stream_and_collect("tweets/search/stream", array_class: Set)
      end

      assert_kind_of Set, results[0]["ids"]
    end

    def test_with_default_custom_classes
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct, default_array_class: Set)
      results = with_stubbed_stream(chunks: ["{\"ids\":[1,2,2,3]}\r\n"], client:) do
        stream_and_collect("tweets/search/stream", client:)
      end

      assert_kind_of OpenStruct, results[0]
      assert_kind_of Set, results[0].ids
    end

    def test_raises_on_error
      stub_request(:get, "https://api.x.com/2/tweets/search/stream")
        .to_return(status: 401, body: '{"errors":[{"message":"Unauthorized"}]}',
          headers: {"Content-Type" => "application/json"})

      assert_raises(Unauthorized) do
        streaming.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end
    end

    def test_includes_authentication
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        streaming.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_match(/Bearer #{TEST_BEARER_TOKEN}/o, request["Authorization"])
    end

    def test_builds_get_request
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        streaming.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_instance_of Net::HTTP::Get, request
    end

    def test_with_params
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        streaming.stream("tweets/sample/stream", params: {"tweet.fields": %w[id text], expansions: nil}) { |_json| flunk "unexpected yield" }
      end

      assert_equal URI("https://api.x.com/2/tweets/sample/stream?tweet.fields=id,text"), request.uri
    end

    def test_a_stream_without_a_block_raises_before_it_connects
      stream = stub_request(:get, "https://api.x.com/2/tweets/search/stream")
      error = assert_raises(ArgumentError) { streaming.stream("tweets/search/stream") }

      assert_equal StreamingClient::NO_BLOCK_MESSAGE, error.message
      assert_not_requested stream
    end

    def test_uses_base_url
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        streaming.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_equal URI("https://api.x.com/2/tweets/search/stream"), request.uri
    end
  end
end
