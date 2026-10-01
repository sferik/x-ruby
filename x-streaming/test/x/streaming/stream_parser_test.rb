# frozen_string_literal: true

require "json"
require "ostruct"
require_relative "../../test_helper"

module X
  class StreamParserTest < Minitest::Test
    cover Streaming.const_get(:StreamParser)

    def setup
      @stream_parser = Streaming.const_get(:StreamParser).new
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

    def test_process_builds_each_document_with_a_response_builder
      results = process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n{\"data\":{\"id\":\"2\"}}"],
        object_class: ResponseBuilder, client: :client)

      assert_equal [{"data" => {"id" => "1"}}, {"data" => {"id" => "2"}}], results.map { |built| built[:body] }
      assert_equal %i[client client], results.map { |built| built[:client] }
    end

    def test_process_remaining_strips_trailing_whitespace
      assert_equal 1, process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n\r"]).length
    end

    private

    def process_and_collect(chunks:, array_class: Array, object_class: Hash, client: nil)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| chunks.each(&block) }
      results = []
      @stream_parser.process(response:, array_class:, object_class:, client:, on_line: ->(_line) {}, on_keep_alive: -> {}) { |json| results << json }
      results
    end
  end
end
