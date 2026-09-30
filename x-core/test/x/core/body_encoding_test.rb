# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Net::HTTP reads a body as binary, where webmock hands over the String it was given, and webmock reads the body of
  # a stream before the stream does, even with net connections allowed, so these read what a server on the loopback
  # interface sends, with webmock disabled
  class BodyEncodingTest < Minitest::Test
    include LocalServer

    cover Core.const_get(:Connection)
    cover Core.const_get(:ResponseParser)
    cover Core.const_get(:StreamParser)

    def http_response(status, body, content_type: "application/json")
      "HTTP/1.1 #{status}\r\nContent-Type: #{content_type}\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
    end

    def with_client(response, &)
      WebMock.disable!
      with_local_server(response:) do |port|
        yield Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/", max_retries: 0)
      end
    ensure
      WebMock.enable!
    end

    def test_the_body_of_a_response_is_utf_8
      body = nil

      with_client(http_response("200 OK", '{"data":{"name":"café"}}')) do |client|
        assert_equal({"data" => {"name" => "café"}}, client.get("users/me") { |response| body = response.body })
      end

      assert_equal Encoding::UTF_8, body.encoding
      assert_includes body, "é"
    end

    def test_the_body_of_an_http_error_is_utf_8
      with_client(http_response("400 Bad Request", '{"title":"Invalid","detail":"café"}')) do |client|
        error = assert_raises(BadRequest) { client.get("users/me") }

        assert_includes error.body, "é"
        assert_equal "GET /users/me: Invalid: café", error.message
      end
    end

    def test_the_body_of_an_invalid_response_is_utf_8
      with_client(http_response("200 OK", "<p>café</p>", content_type: "text/html")) do |client|
        error = assert_raises(InvalidResponse) { client.get("users/me") }

        assert_includes error.body, "é"
      end
    end

    def test_a_body_that_is_not_utf_8_keeps_its_bytes
      with_client(http_response("200 OK", "caf\xE9".b, content_type: "text/plain")) do |client|
        body = assert_raises(InvalidResponse) { client.get("users/me") }.body

        assert_equal [Encoding::UTF_8, false, "caf\xE9".b], [body.encoding, body.valid_encoding?, body.b]
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

    def test_the_body_of_a_stream_that_failed_is_utf_8
      bodies = []
      with_client(http_response("400 Bad Request", '{"title":"Invalid","detail":"café"}')) do |client|
        error = assert_raises(BadRequest) do
          client.with(on_response: ->(response) { bodies << response.body }).streaming(max_reconnects: 0).stream("tweets/search/stream") { |_| }
        end

        assert_includes error.body, "é"
      end

      assert_equal [Encoding::UTF_8], bodies.map(&:encoding)
    end
  end
end
