# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A body read from the response of the transport, the escape hatch, is not known to read_body, which raises an Error
  # of the caller's own for a body that left it none to read, rather than one of the socket, or of Ruby's; these read
  # what a server on the loopback interface sends, with webmock disabled, and count the requests it was sent
  class StreamResponseTransportReadTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
    cover Core.const_get(:StreamBody)

    # A response whose body ends
    WHOLE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"
    # The message of X::StreamResponse for a body the transport read, which is private about the constant that holds it
    READ_ELSEWHERE = "The body of the stream was read from its http_response, which leaves read_body none to read"

    def test_a_body_read_whole_again_is_not_read_from_the_transport_again
      bodies = reading do |response|
        first = response.read_body
        response.http_response.define_singleton_method(:read_body) { raise IOError, "the transport was read again" }
        [first, response.read_body]
      end

      assert_equal ["{}", "{}"], bodies
    end

    def test_a_body_the_transport_passed_to_a_block_is_not_passed_to_a_block_again
      misread = misreading do |response|
        response.http_response.read_body { |_chunk| }
        response.read_body { |_chunk| }
      end

      assert_equal [Error, READ_ELSEWHERE, 1], misread
    end

    def test_a_body_the_transport_passed_to_a_block_is_not_read_whole
      misread = misreading do |response|
        response.http_response.read_body { |_chunk| }
        response.read_body
      end

      assert_equal [Error, READ_ELSEWHERE, 1], misread
    end

    def test_a_body_the_transport_read_whole_is_not_passed_to_a_block
      misread = misreading do |response|
        response.http_response.read_body
        response.read_body { |_chunk| }
      end

      assert_equal [Error, READ_ELSEWHERE, 1], misread
    end

    def test_a_body_the_transport_read_whole_is_read_whole
      body = reading do |response|
        response.http_response.read_body
        response.read_body
      end

      assert_equal ["{}", Encoding::UTF_8], [body, body.encoding]
    end

    def test_an_io_error_of_the_block_is_raised_as_it_was_whatever_it_says
      closed = IOError.new("Net::HTTPOK#read_body called twice")

      assert_same closed, assert_raises(IOError) { reading { |response| response.read_body { |_chunk| raise closed } } }
    end

    def test_another_io_error_of_the_transport_is_a_network_error
      error = assert_raises(NetworkError) do
        reading do |response|
          response.http_response.define_singleton_method(:read_body) { raise IOError, "#read_body called twice, or so" }
          response.read_body
        end
      end

      assert_equal ["GET /2/stream: Network error: #read_body called twice, or so", IOError], [error.message, error.cause.class]
    end

    private

    # Yield the response of a stream a server on the loopback interface answers
    def reading(response = WHOLE, &)
      with_local_connections([response]) { |port, _requests| client(port).get_stream("stream", &) }
    end

    # Yield the response of a stream opened within with_retries, with retries left and a server that would answer
    # each, and return the class and message of the error it raises, and the number of requests the server was sent
    def misreading(response = WHOLE, &)
      with_local_connections(*[[response]] * 3) do |port, requests|
        client = client(port)
        error = assert_raises(Error) { client.with_retries { client.get_stream("stream", &) } }
        [error.class, error.message, requests.size]
      end
    end

    # A client of the server on the port, which sends a request again twice
    def client(port) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", max_retries: 2)
  end
end
