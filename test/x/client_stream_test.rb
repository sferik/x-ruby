require "json"
require_relative "../test_helper"

module X
  class ClientStreamTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_stream_yields_json_objects
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream")
      end

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_stream_with_headers
      mock_response = mock_streaming_response(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"])
      headers = {"User-Agent" => "Custom Agent"}
      request = with_stream_request(mock_response) do
        stream_and_collect("tweets/search/stream", headers:)
      end

      assert_equal "Custom Agent", request["User-Agent"]
    end

    def test_stream_with_custom_object_class
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream", object_class: OpenStruct)
      end

      assert_kind_of OpenStruct, results[0]
    end

    def test_stream_with_custom_array_class
      results = with_stubbed_stream(chunks: ["{\"ids\":[1,2,2,3]}\r\n"]) do
        stream_and_collect("tweets/search/stream", array_class: Set)
      end

      assert_kind_of Set, results[0]["ids"]
    end

    def test_stream_with_default_custom_classes
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct, default_array_class: Set)
      results = with_stubbed_stream(chunks: ["{\"ids\":[1,2,2,3]}\r\n"], client:) do
        stream_and_collect("tweets/search/stream", client:)
      end

      assert_kind_of OpenStruct, results[0]
      assert_kind_of Set, results[0].ids
    end

    def test_stream_raises_on_error
      stub_request(:get, "https://api.twitter.com/2/tweets/search/stream")
        .to_return(status: 401, body: '{"errors":[{"message":"Unauthorized"}]}',
          headers: {"Content-Type" => "application/json"})

      assert_raises(Unauthorized) do
        @client.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end
    end

    def test_stream_includes_authentication
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        @client.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_match(/Bearer #{TEST_BEARER_TOKEN}/o, request["Authorization"])
    end

    def test_stream_builds_get_request
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        @client.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_instance_of Net::HTTP::Get, request
    end

    def test_stream_uses_base_url
      mock_response = mock_streaming_response(chunks: [])
      request = with_stream_request(mock_response) do
        @client.stream("tweets/search/stream") { |_json| flunk "unexpected yield" }
      end

      assert_equal URI("https://api.twitter.com/2/tweets/search/stream"), request.uri
    end

    private

    def stream_and_collect(endpoint, client: @client, **options)
      results = []
      client.stream(endpoint, **options) { |json| results << json }
      results
    end

    def with_stubbed_stream(chunks:, client: @client, &test_block)
      mock_response = mock_streaming_response(chunks:)
      connection = client.instance_variable_get(:@connection)
      connection.stub(:perform_stream, ->(**_, &block) { block.call(mock_response) }, &test_block)
    end

    def with_stream_request(mock_response, client: @client, &test_block)
      captured_request = nil
      connection = client.instance_variable_get(:@connection)
      connection.stub(:perform_stream, lambda { |request:, &block|
        captured_request = request
        block.call(mock_response)
      }, &test_block)
      captured_request
    end

    def mock_streaming_response(chunks:)
      response = Minitest::Mock.new
      response.expect(:is_a?, true, [Net::HTTPSuccess])
      response.expect(:read_body, nil) do |&block|
        chunks.each { |chunk| block.call(chunk) }
      end
      response
    end
  end
end
