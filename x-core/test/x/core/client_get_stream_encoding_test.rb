# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a stream that failed is read whole, by on_response and by its error, as UTF-8; webmock hands over the
  # String it was given, so this reads what a server on the loopback interface sends, with webmock disabled
  class ClientGetStreamEncodingTest < Minitest::Test
    include LocalServer

    cover_client

    BODY = '{"title":"Invalid","detail":"café"}'
    HTML = "<html>Service Unavailable — try later</html>"

    def test_the_body_of_a_stream_that_failed_is_utf_8
      bodies = []
      error = with_failed_stream do |port|
        client = Client.new(base_url: "http://127.0.0.1:#{port}/", on_response: ->(response) { bodies << response.body })
        assert_raises(BadRequest) { client.get_stream("stream") { |_response| } }
      end

      assert_equal [BODY, Encoding::UTF_8], [error.body, error.body.encoding]
      assert_equal [Encoding::UTF_8], bodies.map(&:encoding)
    end

    def test_the_body_of_a_stream_that_failed_is_read_after_the_stream_ends_with_no_on_response
      error = with_failed_stream(content_type: "text/html", body: HTML) do |port|
        assert_raises(ServiceUnavailable) { Client.new(base_url: "http://127.0.0.1:#{port}/").get_stream("stream") { |_response| } }
      end

      assert_equal [HTML, Encoding::UTF_8], [error.body, error.body.encoding]
    end

    private

    # Yield the port of a server that answers a stream with a failure, with webmock disabled
    def with_failed_stream(content_type: "application/json", body: BODY, &)
      status = content_type.eql?("text/html") ? "503 Service Unavailable" : "400 Bad Request"
      WebMock.disable!
      with_local_server(response: "HTTP/1.1 #{status}\r\nContent-Type: #{content_type}\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}", &)
    ensure
      WebMock.enable!
    end
  end
end
