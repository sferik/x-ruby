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
      @stream_parser.process(response:, array_class: Array, object_class: Hash, client: nil, on_line: ->(line) { events << line },
        on_keep_alive: -> { events << :keep_alive }) { |json| events << json }

      assert_equal ['{"a":1}', {"a" => 1}, :keep_alive, '{"b":2}', {"b" => 2}], events
    end

    def test_process_calls_on_keep_alive_for_each_empty_line_alone
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| ["\r\n", "\r", "\n{\"a\":1}\r\n", "\r\n  "].each(&block) }
      events = []
      @stream_parser.process(response:, array_class: Array, object_class: Hash, client: nil, on_line: ->(_line) {},
        on_keep_alive: -> { events << :keep_alive }) { |json| events << json }

      assert_equal [:keep_alive, :keep_alive, {"a" => 1}, :keep_alive], events
    end
  end
end
