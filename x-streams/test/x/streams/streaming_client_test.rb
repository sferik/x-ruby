# frozen_string_literal: true

require "json"
require "ostruct"
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

    def test_a_stream_without_a_block_raises_before_it_connects
      stream = stub_request(:get, "https://api.x.com/2/tweets/search/stream")
      error = assert_raises(ArgumentError) { streaming.stream("tweets/search/stream") }

      assert_equal "stream takes a block, which receives each object the stream delivers", error.message
      assert_not_requested stream
    end

    def test_the_stream_is_a_get_of_the_endpoint_with_the_credentials_and_headers_of_the_client
      stream = stub_request(:get, "https://api.x.com/2/tweets/search/stream")
        .with(headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}", "User-Agent" => "Custom Agent"})
      until_the_stream_ends { streaming.stream("tweets/search/stream", headers: {"User-Agent" => "Custom Agent"}) { |_json| flunk "unexpected yield" } }

      assert_requested stream, times: 1
    end

    def test_the_stream_takes_query_parameters
      stream = stub_request(:get, "https://api.x.com/2/tweets/sample/stream?tweet.fields=id,text")
      until_the_stream_ends { streaming.stream("tweets/sample/stream", params: {"tweet.fields": %w[id text], expansions: nil}) { |_json| flunk "unexpected yield" } }

      assert_requested stream, times: 1
    end

    def test_an_endpoint_with_a_leading_slash_is_relative_to_the_base_url
      stream = stub_request(:get, "https://example.com/2/tweets/search/stream")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "https://example.com/2/")
      until_the_stream_ends { streaming(client:).stream("/tweets/search/stream") { |_json| flunk "unexpected yield" } }

      assert_requested stream, times: 1
    end

    def test_an_endpoint_that_is_not_a_url_raises
      assert_raises(ArgumentError) { streaming.stream("http://[bad") { |_json| flunk "unexpected yield" } }
    end
  end
end
