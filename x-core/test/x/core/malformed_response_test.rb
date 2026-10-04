# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response whose headers Net::HTTP cannot read, read from a server on the loopback interface, since webmock builds
  # the response itself, is a NetworkError, as every failure of the network is, whether it is requested or streamed
  class MalformedResponseTest < Minitest::Test
    include LocalServer

    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionRequest)

    MALFORMED = {
      "an unreadable Content-Length" => "HTTP/1.1 200 OK\r\nContent-Length: abc\r\n\r\n{}",
      "an unreadable Content-Range" => "HTTP/1.1 200 OK\r\nContent-Range: zzz\r\nConnection: close\r\n\r\n{}",
      "a bare CR in a header value" => "HTTP/1.1 200 OK\r\nX-A: a\rb\r\nContent-Length: 2\r\n\r\n{}"
    }.freeze

    def client(port) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", max_retries: 0)

    def test_a_response_whose_headers_cannot_be_read_is_a_network_error
      MALFORMED.each do |name, response|
        with_local_server(response:) { |port| assert_raises(NetworkError, name) { client(port).get("users/me") } }
      end
    end

    def test_a_stream_whose_headers_cannot_be_read_is_a_network_error
      MALFORMED.each do |name, response|
        with_local_server(response:) do |port|
          assert_raises(NetworkError, name) { client(port).get_stream("tweets/sample/stream") { |body| body.read_body { nil } } }
        end
      end
    end
  end
end
