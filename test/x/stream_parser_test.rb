require "json"
require_relative "../test_helper"

module X
  class StreamParserTest < Minitest::Test
    cover StreamParser

    def setup
      @stream_parser = StreamParser.new
      @response_parser = ResponseParser.new
    end

    def test_process_yields_json_objects
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"])

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_yields_multiple_objects
      results = process_and_collect(
        chunks: ["{\"data\":{\"id\":\"1\"}}\r\n{\"data\":{\"id\":\"2\"}}\r\n"]
      )

      assert_equal [{"data" => {"id" => "1"}}, {"data" => {"id" => "2"}}], results
    end

    def test_process_handles_split_across_chunks
      results = process_and_collect(chunks: ["{\"data\":{\"id\"", ":\"1\"}}\r\n"])

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_handles_split_delimiter
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r", "\n"])

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_skips_heartbeats
      results = process_and_collect(
        chunks: ["{\"data\":{\"id\":\"1\"}}\r\n", "\r\n", "{\"data\":{\"id\":\"2\"}}\r\n"]
      )

      assert_equal 2, results.length
      assert_equal "1", results[0]["data"]["id"]
      assert_equal "2", results[1]["data"]["id"]
    end

    def test_process_handles_remaining_buffer
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}"])

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_handles_empty_stream
      assert_empty process_and_collect(chunks: [])
    end

    def test_process_handles_heartbeat_only_stream
      assert_empty process_and_collect(chunks: ["\r\n", "\r\n"])
    end

    def test_process_with_custom_object_class
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"], object_class: OpenStruct)

      assert_kind_of OpenStruct, results[0]
      assert_kind_of OpenStruct, results[0].data
    end

    def test_process_with_custom_array_class
      results = process_and_collect(chunks: ["{\"ids\":[1,2,2,3]}\r\n"], array_class: Set)

      assert_kind_of Set, results[0]["ids"]
    end

    def test_process_remaining_with_custom_object_class
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}"], object_class: OpenStruct)

      assert_kind_of OpenStruct, results[0]
    end

    def test_process_remaining_with_custom_array_class
      results = process_and_collect(chunks: ["{\"ids\":[1,2,2,3]}"], array_class: Set)

      assert_kind_of Set, results[0]["ids"]
    end

    def test_process_remaining_strips_trailing_whitespace
      assert_equal 1, process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n\r"]).length
    end

    def test_process_raises_on_error_response
      stub_request(:get, "https://api.twitter.com/2/tweets/search/stream")
        .to_return(status: 401, body: '{"errors":[{"message":"Unauthorized"}]}',
          headers: {"Content-Type" => "application/json"})
      response = Net::HTTP.get_response(URI("https://api.twitter.com/2/tweets/search/stream"))

      assert_raises(Unauthorized) do
        @stream_parser.process(response:, response_parser: @response_parser) do |_json|
          flunk "unexpected yield"
        end
      end
    end

    private

    def process_and_collect(chunks:, **options)
      response = mock_streaming_response(chunks:)
      results = []
      @stream_parser.process(response:, response_parser: @response_parser, **options) { |json| results << json }
      results
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
