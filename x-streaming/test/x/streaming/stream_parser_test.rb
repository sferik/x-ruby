# frozen_string_literal: true

require "json"
require "ostruct"
require_relative "../../test_helper"

module X
  class StreamParserTest < Minitest::Test
    cover Streaming.const_get(:StreamParser)

    # A Hash that is told apart from the Hash of a parse, so that the object a line is built into says which it is
    class RecordingHash < Hash
    end

    # An Array that is told apart from the Array of a parse, so that the array a line is built into says which it is
    class RecordingArray < Array
    end

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

    def test_process_builds_each_line_into_the_classes_as_json_parse_does
      line = "{\"data\":[{\"ids\":[1,[2,{\"a\":null}]],\"b\":\"c\"},3,\"d\"],\"e\":{\"f\":[]},\"g\":true}"
      results = process_and_collect(chunks: [line], array_class: RecordingArray, object_class: RecordingHash)

      assert_equal [shape(JSON.parse(line, array_class: RecordingArray, object_class: RecordingHash))], results.map { |result| shape(result) }
      assert_equal [JSON.parse(line)], results
    end

    def test_process_builds_a_line_that_holds_neither_an_object_nor_an_array_as_it_was_parsed
      assert_equal ["ruby", 1], process_and_collect(chunks: ["\"ruby\"\r\n1"], array_class: Set, object_class: OpenStruct)
    end

    def test_process_parses_each_line_once
      parses = []
      parse = JSON.method(:parse)
      JSON.stub(:parse, ->(*args, **options) { (parses << args.first) && parse.call(*args, **options) }) do
        process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n{\"data\":[1]}"], array_class: Set, object_class: OpenStruct)
      end

      assert_equal ["{\"data\":{\"id\":\"1\"}}", "{\"data\":[1]}"], parses
    end

    def test_process_remaining_strips_trailing_whitespace
      assert_equal 1, process_and_collect(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n\r"]).length
    end

    private

    # The classes of a value and of all it holds, beside what it holds, which == alone does not compare
    def shape(value)
      case value
      when Hash then [value.class, value.to_h { |key, item| [key, shape(item)] }]
      when Array then [value.class, value.map { |item| shape(item) }]
      else value
      end
    end

    def process_and_collect(chunks:, array_class: Array, object_class: Hash, client: nil)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| chunks.each(&block) }
      results = []
      @stream_parser.process(response:, array_class:, object_class:, client:, on_line: ->(_line) {}, on_keep_alive: -> {}) { |json| results << json }
      results
    end
  end
end
