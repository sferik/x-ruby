# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  class StreamParserInvalidJSONTest < Minitest::Test
    cover Streams.const_get(:StreamParser)

    def setup
      @stream_parser = Streams.const_get(:StreamParser).new
    end

    def test_process_raises_invalid_response_for_a_line_that_is_not_json
      response = streaming_response(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n<html>\r\n"])
      results = []
      error = assert_raises(InvalidResponse) do
        process(response) { |json| results << json }
      end

      assert_same response, error.http_response
      assert_equal "<html>", error.body
      assert_kind_of JSON::ParserError, error.cause
      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_drops_a_line_the_stream_ended_within_rather_than_raise_for_it
      results = []
      process(streaming_response(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n{\"data\":"])) { |json| results << json }

      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_leaves_the_network_error_of_a_connection_that_drops_while_reading_untagged
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&_block| raise Errno::ECONNRESET }

      error = assert_raises(NetworkError) do
        process(response) { flunk "unexpected yield" }
      end

      assert_instance_of Errno::ECONNRESET, error.cause
    end

    def test_the_error_names_the_request_of_the_stream
      error = assert_raises(InvalidResponse) { process(streaming_response(chunks: ["<html>\r\n"])) { flunk "unexpected yield" } }

      assert_equal [:get, URI("https://api.x.com/2/tweets/search/stream")], [error.http_method, error.uri]
    end

    private

    def process(response, &)
      @stream_parser.process(response: stream_response(response), array_class: Array, object_class: Hash, client: nil, on_line: ->(_line) {}, on_keep_alive: -> {}, &)
    end

    def streaming_response(chunks:)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.uri = URI("https://api.x.com/2/tweets/search/stream")
      response.define_singleton_method(:read_body) { |&block| chunks.each(&block) }
      response
    end
  end
end
