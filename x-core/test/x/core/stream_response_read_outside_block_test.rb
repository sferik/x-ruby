# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a stream is read inside the block of get_stream, and a read of a response that outlived the block,
  # whose connection is closed, raises an Error of the caller's own, rather than one of the socket; these read what a
  # server on the loopback interface sends, with webmock disabled
  class StreamResponseReadOutsideBlockTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
    cover Core.const_get(:StreamBody)

    # A response whose body ends
    WHOLE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"
    # A response whose connection drops partway through its body
    TRUNCATED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"
    # The message of X::StreamResponse for a read outside the block, which is private about the constant that holds it
    READ_OUTSIDE_BLOCK = "The body of a stream is read inside the block of get_stream, which has returned, and " \
      "closed the connection the body is read from"

    def test_a_response_that_left_the_block_of_get_stream_is_not_read
      escaped = reading { |response| response }

      assert_equal [[Error, READ_OUTSIDE_BLOCK]] * 2, [raised { escaped.read_body }, raised { escaped.read_body { |_chunk| } }]
    end

    def test_a_response_that_left_the_block_of_get_stream_is_not_read_within_with_retries
      with_local_connections(*[[WHOLE]] * 3) do |port, requests|
        client = client(port)
        error = assert_raises(Error) { client.with_retries { client.get_stream("stream", &:itself).read_body } }

        assert_equal [Error, READ_OUTSIDE_BLOCK, 1], [error.class, error.message, requests.size]
      end
    end

    def test_a_body_read_whole_is_not_returned_once_the_response_left_the_block_of_get_stream
      escaped = reading { |response| response.tap(&:read_body) }

      assert_equal [Error, READ_OUTSIDE_BLOCK], raised { escaped.read_body }
    end

    def test_a_response_whose_block_raised_is_not_read
      escaped = nil
      assert_raises(ArgumentError) { reading { |response| raise ArgumentError, (escaped = response).status.to_s } }

      assert_equal [Error, READ_OUTSIDE_BLOCK], raised { escaped.read_body }
    end

    def test_a_response_whose_body_dropped_is_not_read_once_the_block_has_raised_for_it
      escaped = nil
      assert_raises(NetworkError) { reading(TRUNCATED) { |response| (escaped = response).read_body } }

      assert_equal [Error, READ_OUTSIDE_BLOCK], raised { escaped.read_body }
    end

    private

    # The class and message of the error the block raises
    def raised(&) = assert_raises(Error, &).then { |error| [error.class, error.message] }

    # Yield the response of a stream a server on the loopback interface answers
    def reading(response = WHOLE, &)
      with_local_connections([response]) { |port, _requests| client(port).get_stream("stream", &) }
    end

    # A client of the server on the port, which sends a request again twice
    def client(port) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", max_retries: 2)
  end
end
