# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a stream that failed is read whole, by on_response and by its error, as UTF-8; webmock hands over the
  # String it was given, so this reads what a server on the loopback interface sends, with webmock disabled
  class ClientGetStreamEncodingTest < Minitest::Test
    include LocalServer

    cover_client

    BODY = '{"title":"Invalid","detail":"café"}'

    def test_the_body_of_a_stream_that_failed_is_utf_8
      bodies = []
      error = with_failed_stream do |port|
        client = Client.new(base_url: "http://127.0.0.1:#{port}/", on_response: ->(response) { bodies << response.body })
        assert_raises(BadRequest) { client.get_stream("stream") { |_response| } }
      end

      assert_equal [BODY, Encoding::UTF_8], [error.body, error.body.encoding]
      assert_equal [Encoding::UTF_8], bodies.map(&:encoding)
    end

    private

    # Yield the port of a server that answers a stream with a failure whose body is not ASCII, with webmock disabled
    def with_failed_stream(&)
      WebMock.disable!
      with_local_server(response: "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: #{BODY.bytesize}\r\n\r\n#{BODY}", &)
    ensure
      WebMock.enable!
    end
  end
end
