# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a stream is read once, and a second read raises an Error of the caller's own, rather than one of the
  # socket, which with_retries would open the stream again for, unless both reads are whole; these read what a server
  # on the loopback interface sends, with webmock disabled, and count the requests it was sent
  class StreamResponseReadOnceTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
    cover Core.const_get(:StreamBody)

    # A response whose body ends
    WHOLE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"
    # A response without a body
    BODILESS = "HTTP/1.1 204 No Content\r\n\r\n"
    # A response whose connection drops partway through its body
    TRUNCATED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"
    # The message of X::StreamResponse for a second read, which is private about the constant that holds it
    READ_ONCE = "The body of a stream is read once, and read_body has read it, whole or in part. Only a body read " \
      "whole, without a block, is returned again"

    def test_a_body_read_through_a_block_is_not_read_through_a_block_again
      chunks = []
      misread = misreading do |response|
        response.read_body { |chunk| chunks << chunk }
        response.read_body { |chunk| chunks << chunk }
      end

      assert_equal [[Error, READ_ONCE, 1], ["{}"]], [misread, chunks]
    end

    def test_a_body_read_whole_is_not_read_through_a_block
      chunks = []
      misread = misreading do |response|
        response.read_body
        response.read_body { |chunk| chunks << chunk }
      end

      assert_equal [[Error, READ_ONCE, 1], []], [misread, chunks]
    end

    def test_a_body_read_through_a_block_is_not_read_whole
      misread = misreading do |response|
        response.read_body { |_chunk| }
        response.read_body
      end

      assert_equal [Error, READ_ONCE, 1], misread
    end

    def test_a_body_whose_block_was_left_with_break_is_not_read_again
      misread = misreading do |response|
        response.read_body { |_chunk| break }
        response.read_body
      end

      assert_equal [Error, READ_ONCE, 1], misread
    end

    def test_a_body_whose_block_was_left_with_throw_is_not_read_again
      misread = misreading do |response|
        catch(:left) { response.read_body { |_chunk| throw :left } }
        response.read_body { |_chunk| }
      end

      assert_equal [Error, READ_ONCE, 1], misread
    end

    def test_a_body_whose_block_raised_is_not_read_again
      misread = misreading do |response|
        begin
          response.read_body { |_chunk| raise ArgumentError, "the chunk was refused" }
        rescue ArgumentError
          nil
        end
        response.read_body
      end

      assert_equal [Error, READ_ONCE, 1], misread
    end

    def test_a_body_that_dropped_while_it_was_read_whole_is_not_read_again
      misread = misreading(TRUNCATED) do |response|
        begin
          response.read_body
        rescue NetworkError
          nil
        end
        response.read_body
      end

      assert_equal [Error, READ_ONCE, 1], misread
    end

    def test_a_body_read_whole_is_returned_again_as_a_string_of_its_own
      first, second = reading(&read_twice)

      assert_equal ["{}", "{}", Encoding::UTF_8, Encoding::UTF_8], [first, second, first.encoding, second.encoding]
      refute_same first, second
    end

    def test_a_response_without_a_body_has_none_to_read_however_often_it_is_read
      assert_equal [nil, nil], reading(BODILESS, &read_twice)
    end

    def test_a_body_is_read_on_another_thread_inside_the_block
      assert_equal "{}", reading { |response| Thread.new { response.read_body }.value }
    end

    private

    # A block that reads the body of a response whole, twice
    def read_twice = ->(response) { [response.read_body, response.read_body] }

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
