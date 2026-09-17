require "json"
require_relative "../../test_helper"

module X
  class StreamParserInvalidJSONTest < Minitest::Test
    cover StreamParser

    def setup
      @stream_parser = StreamParser.new
      @response_parser = ResponseParser.new
    end

    def test_process_raises_invalid_response_for_a_line_that_is_not_json
      response = streaming_response(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n<html>\r\n"])
      results = []
      error = assert_raises(InvalidResponse) do
        @stream_parser.process(response:, response_parser: @response_parser) { |json| results << json }
      end

      assert_same response, error.response
      assert_equal "<html>", error.body
      assert_kind_of JSON::ParserError, error.cause
      assert_equal [{"data" => {"id" => "1"}}], results
    end

    def test_process_raises_invalid_response_for_remaining_data_that_is_not_json
      response = streaming_response(chunks: ["{\"data\":"])

      error = assert_raises(InvalidResponse) { @stream_parser.process(response:, response_parser: @response_parser) { flunk "unexpected yield" } }

      assert_equal "{\"data\":", error.body
    end

    private

    def streaming_response(chunks:)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| chunks.each(&block) }
      response
    end
  end
end
