# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  class StreamParserOnLineTest < Minitest::Test
    cover Streaming.const_get(:StreamParser)

    def setup
      @stream_parser = Streaming.const_get(:StreamParser).new
    end

    def test_process_passes_each_line_to_on_line_before_decoding_it
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| ["{\"a\":1}\r\n\r\n{\"b\"", ":2}"].each(&block) }
      events = []
      @stream_parser.process(response:, array_class: Array, object_class: Hash, client: nil, on_line: ->(line) { events << line }) { |json| events << json }

      assert_equal ['{"a":1}', {"a" => 1}, '{"b":2}', {"b" => 2}], events
    end
  end
end
