# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # A line of a stream that holds errors and no data raises StreamError, whatever the objects of the stream are built
  # as, and the stream reconnects after one that holds operational-disconnects alone
  class StreamErrorTest < Minitest::Test
    cover StreamError
    cover Core.const_get(:StreamParser)
    cover Core.const_get(:ReconnectHandler)
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/search/stream"
    DISCONNECT = {"title" => "operational-disconnect", "disconnect_type" => "UpstreamOperationalDisconnect",
                  "detail" => "This stream has been disconnected upstream for operational reasons.",
                  "type" => "https://api.twitter.com/2/problems/operational-disconnect"}.freeze
    DISCONNECT_LINE = "#{JSON.generate({"errors" => [DISCONNECT]})}\r\n"
    REFUSAL = {"title" => "ConnectionException", "detail" => "This stream is currently at the maximum allowed connection limit.",
               "type" => "https://api.x.com/2/problems/streaming-connection"}.freeze
    REFUSAL_LINE = "#{JSON.generate({"errors" => [REFUSAL]})}\r\n"

    # Builds an object of the data of a line, as the resource classes of x-objects do, and nil of a line without any
    class DataBuilder
      def self.from_response(body, client:, **) = body["data"]&.then { |data| {id: data["id"], client:} }
    end

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_a_line_of_errors_alone_raises_stream_error_for_an_object_class
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n#{REFUSAL_LINE}")
      received = []
      error = assert_raises(StreamError) do
        @client.streaming.stream("tweets/search/stream", object_class: DataBuilder) { |post| received << post[:id] }
      end

      assert_equal ["1"], received
      assert_equal "GET /2/tweets/search/stream: ConnectionException: #{REFUSAL["detail"]}", error.message
      assert_equal [:get, URI(STREAM_URL)], [error.http_method, error.uri]
    end

    def test_a_stream_error_holds_the_problems_of_the_line_frozen
      stub_request(:get, STREAM_URL).to_return(body: REFUSAL_LINE)
      error = assert_raises(StreamError) { @client.streaming.stream("tweets/search/stream", object_class: DataBuilder) { flunk "unexpected yield" } }

      assert_equal [REFUSAL], error.problems.map(&:to_h)
      assert_predicate error.problems, :frozen?
    end

    def test_a_stream_error_freezes_a_copy_of_the_problems_it_is_given
      problems = []
      error = StreamError.new(problems)

      assert_predicate error.problems, :frozen?
      refute_predicate problems, :frozen?
    end

    def test_on_response_is_passed_the_line_of_errors_before_it_raises
      stub_request(:get, STREAM_URL).to_return(body: REFUSAL_LINE)
      bodies = []
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(response) { bodies << response.body })

      assert_raises(StreamError) { client.streaming.stream("tweets/search/stream", object_class: DataBuilder) { flunk "unexpected yield" } }
      assert_equal [REFUSAL_LINE.chomp], bodies
    end

    def test_a_line_of_errors_alone_raises_stream_error_without_an_object_class
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n#{REFUSAL_LINE}")
      received = []

      error = assert_raises(StreamError) { @client.streaming.stream("tweets/search/stream") { |json| received << json } }
      assert_equal [{"data" => {"id" => "1"}}], received
      assert_equal [REFUSAL], error.problems.map(&:to_h)
    end

    def test_a_line_of_errors_alone_raises_stream_error_for_an_object_class_that_parses_json
      stub_request(:get, STREAM_URL).to_return(body: REFUSAL_LINE)

      assert_raises(StreamError) { @client.streaming.stream("tweets/search/stream", object_class: Struct.new(:data)) { flunk "unexpected yield" } }
    end

    def test_a_line_is_decoded_into_the_classes_asked_for
      stub_request(:get, STREAM_URL).to_return(body: "{\"data\":{\"ids\":[\"1\"]}}\r\n")
      object_class = Class.new(Hash)
      array_class = Class.new(Array)
      received = []
      @client.streaming(max_reconnects: 0).stream("tweets/search/stream", array_class:, object_class:) { |json| received << json }

      assert_instance_of object_class, received.first
      assert_instance_of array_class, received.first["data"]["ids"]
    end

    def test_a_line_that_holds_data_beside_errors_is_built
      body = JSON.generate({"data" => {"id" => "1"}, "errors" => [DISCONNECT]})
      stub_request(:get, STREAM_URL).to_return(body: "#{body}\r\n")
      received = []
      @client.streaming(max_reconnects: 0).stream("tweets/search/stream", object_class: DataBuilder) { |post| received << post[:id] }

      assert_equal ["1"], received
    end

    def test_a_line_of_no_errors_is_passed_to_the_object_class
      stub_request(:get, STREAM_URL).to_return(body: "{\"errors\":[]}\r\n[1]\r\n")
      received = []
      builder = Class.new { def self.from_response(body, client:, **) = body }
      @client.streaming(max_reconnects: 0).stream("tweets/search/stream", object_class: builder) { |json| received << json }

      assert_equal [{"errors" => []}, [1]], received
    end

    def test_a_line_of_no_errors_is_yielded_as_a_hash
      stub_request(:get, STREAM_URL).to_return(body: "{\"errors\":[]}\r\n[1]\r\n")
      received = []
      @client.streaming(max_reconnects: 0).stream("tweets/search/stream") { |json| received << json }

      assert_equal [{"errors" => []}, [1]], received
    end

    def test_the_message_joins_each_problem
      problems = [Problem.new({"title" => "A", "detail" => "first"}), Problem.new({"message" => "second"})]
      error = StreamError.new(problems)

      assert_equal "A: first, second", error.message
      assert_nil error.http_method
    end
  end
end
