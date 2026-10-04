# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a stream read whole is UTF-8, as the body of any other response is, and its chunks are binary; webmock
  # hands over the String it was given, so these read what a server on the loopback interface sends, with webmock
  # disabled
  class StreamResponseBodyTest < Minitest::Test
    include LocalServer

    cover StreamResponse
    cover Core.const_get(:StreamBody)

    def test_a_body_of_ascii_read_whole_is_utf_8
      assert_equal ['{"data":1}', Encoding::UTF_8], reading('{"data":1}') { |response| response.read_body.then { |body| [body, body.encoding] } }
    end

    def test_a_body_of_multi_byte_characters_read_whole_is_utf_8
      body = reading('{"name":"café"}', &:read_body)

      assert_equal ['{"name":"café"}', Encoding::UTF_8], [body, body.encoding]
      assert_includes body, "é"
    end

    def test_a_body_that_is_not_utf_8_read_whole_keeps_its_bytes
      body = reading("caf\xE9".b, &:read_body)

      assert_equal [Encoding::UTF_8, false, "caf\xE9".b, "caf\uFFFD"], [body.encoding, body.valid_encoding?, body.b, body.scrub]
    end

    def test_a_response_without_a_body_has_none_to_read
      assert_equal [204, nil], streaming("HTTP/1.1 204 No Content\r\n\r\n") { |response| [response.status, response.read_body] }
    end

    def test_a_body_read_whole_leaves_the_body_of_the_response_of_the_transport_as_it_was_read
      encodings = reading('{"name":"café"}') { |response| [response.read_body.encoding, response.http_response.body.encoding] }

      assert_equal [Encoding::UTF_8, Encoding::BINARY], encodings
    end

    def test_the_chunks_of_a_body_are_binary
      chunks = []
      reading('{"name":"café"}') { |response| response.read_body { |chunk| chunks << chunk } }

      assert_equal ['{"name":"café"}'.b, [Encoding::BINARY]], [chunks.join, chunks.map(&:encoding).uniq]
    end

    private

    # Yield the response of a stream whose body is the one given
    def reading(body, &) = streaming("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}", &)

    # Yield the response of a stream a server on the loopback interface answers, with webmock disabled
    def streaming(response, &)
      WebMock.disable!
      with_local_server(response:) { |port| Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/").get_stream("stream", &) }
    ensure
      WebMock.enable!
    end
  end
end
