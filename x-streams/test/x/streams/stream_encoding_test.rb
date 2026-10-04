# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Net::HTTP reads the body of a stream as binary, in chunks that can end within a character, where webmock hands over
  # the String it was given, and reads the body before the stream does, so these read what a server on the loopback
  # interface sends, with webmock disabled
  class StreamEncodingTest < Minitest::Test
    include LocalServer

    cover StreamingClient
    cover Streams.const_get(:StreamParser)

    def http_response(status, body)
      "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
    end

    def with_client(response)
      with_local_server(response:) do |port|
        yield Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/", max_retries: 0)
      end
    end

    def test_each_line_of_a_stream_is_utf_8
      bodies = []
      with_client(http_response("200 OK", "{\"text\":\"café\"}\r\n")) do |client|
        post = client.with(on_response: ->(response) { bodies << response.body }).streaming(max_reconnects: 0)
          .stream("tweets/search/stream") { |object| break object }

        assert_equal({"text" => "café"}, post)
      end

      assert_equal ['{"text":"café"}'], bodies
      assert_equal Encoding::UTF_8, bodies.first.encoding
    end

    def test_a_line_of_a_stream_that_is_not_json_is_utf_8
      with_client(http_response("200 OK", "café\r\n")) do |client|
        error = assert_raises(InvalidResponse) { client.streaming(max_reconnects: 0).stream("tweets/search/stream") { |_| } }

        assert_equal ["café", Encoding::UTF_8], [error.body, error.body.encoding]
      end
    end
  end
end
