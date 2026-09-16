require "json"
require_relative "../../test_helper"

module X
  class StreamParserOnBodyTest < Minitest::Test
    include StreamHelpers

    cover StreamParser

    def setup
      @stream_parser = StreamParser.new
      @response_parser = ResponseParser.new
    end

    def test_process_passes_each_line_to_on_body_before_decoding_it
      events = []
      @stream_parser.process(response: mock_streaming_response(chunks: ["{\"a\":1}\r\n\r\n{\"b\"", ":2}"]), response_parser: @response_parser,
        on_body: ->(line) { events << line }) { |json| events << json }

      assert_equal ['{"a":1}', {"a" => 1}, '{"b":2}', {"b" => 2}], events
    end

    def test_process_calls_on_body_before_raising
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(status: 401, body: "{}", headers: {"Content-Type" => "application/json"})
      response = Net::HTTP.get_response(URI("https://api.x.com/2/tweets/search/stream"))
      calls = []

      assert_raises(Unauthorized) { @stream_parser.process(response:, response_parser: @response_parser, on_body: ->(*args) { calls << args }) }
      assert_equal [[]], calls
    end
  end
end
