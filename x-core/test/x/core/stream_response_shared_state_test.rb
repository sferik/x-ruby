# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response counts the reads of its body apart from its own state, so one that was frozen is read as any other is,
  # and a dup or clone of it counts its reads with it, since the body they read is one; these read what a server on
  # the loopback interface sends, with webmock disabled, and count the requests it was sent
  class StreamResponseSharedStateTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
    cover Core.const_get(:StreamBody)

    # A response whose body ends
    WHOLE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"
    # The messages of X::StreamResponse, which is private about the constants that hold them
    READ_ONCE = "The body of a stream is read once, and read_body has read it, whole or in part. Only a body read " \
      "whole, without a block, is returned again"
    READ_OUTSIDE_BLOCK = "The body of a stream is read inside the block of get_stream, which has returned, and " \
      "closed the connection the body is read from"

    READ_DEEP_FROZEN = "The body of a stream cannot be read from a response that was frozen deeply, with what its " \
      "reads are noted in and the connection the body is read from. A response frozen with freeze is read as any other"

    def test_a_response_frozen_deeply_reads_its_status_and_headers
      read = deep_frozen do |response|
        [response.status, response.headers["content-length"], response.rate_limits, response.rate_limit, response.uri.path]
      end

      assert_equal [200, "2", [], nil, "/2/stream"], read
    end

    def test_a_response_frozen_deeply_is_not_read
      misread = deep_frozen { |response| assert_raises(Error) { response.read_body } }

      assert_equal [Error, READ_DEEP_FROZEN], [misread.class, misread.message]
    end

    def test_a_response_frozen_deeply_is_not_read_through_a_block
      chunks = []
      misread = deep_frozen { |response| assert_raises(Error) { response.read_body { |chunk| chunks << chunk } } }

      assert_equal [Error, READ_DEEP_FROZEN, []], [misread.class, misread.message, chunks]
    end

    def test_a_response_frozen_deeply_returns_the_body_it_read_whole_again
      assert_equal ["{}", Encoding::UTF_8], deep_frozen(read: true, &:read_body).then { |body| [body, body.encoding] }
    end

    def test_a_block_that_freezes_the_response_returns_its_value
      assert_equal 200, reading { |response| response.freeze.status }
    end

    def test_a_block_that_freezes_the_response_raises_its_error
      mine = KeyError.new("mine")

      assert_same mine, assert_raises(KeyError) { reading { |response| response.freeze && raise(mine) } }
    end

    def test_a_frozen_response_is_read_whole_and_returned_again
      assert_equal %w[{} {}], reading { |response| [response.freeze.read_body, response.read_body] }
    end

    def test_a_frozen_response_is_read_through_a_block_once
      chunks = []
      misread = misreading do |response|
        response.freeze.read_body { |chunk| chunks << chunk }
        response.read_body { |chunk| chunks << chunk }
      end

      assert_equal [[Error, READ_ONCE, 1], ["{}"]], [misread, chunks]
    end

    def test_a_frozen_response_that_left_the_block_of_get_stream_is_not_read
      escaped = reading(&:freeze)

      assert_equal [Error, READ_OUTSIDE_BLOCK], assert_raises(Error) { escaped.read_body }.then { |error| [error.class, error.message] }
    end

    def test_a_copy_that_left_the_block_of_get_stream_is_not_read
      %i[dup clone].each do |copy|
        assert_equal [Error, READ_OUTSIDE_BLOCK, 1], misreading { |response| response.public_send(copy) }
      end
    end

    def test_a_copy_is_not_read_through_a_block_after_the_response_was
      chunks = []
      misread = misreading do |response|
        copy = response.dup
        response.read_body { |chunk| chunks << chunk }
        copy.read_body { |chunk| chunks << chunk }
      end

      assert_equal [[Error, READ_ONCE, 1], ["{}"]], [misread, chunks]
    end

    def test_a_response_is_not_read_through_a_block_after_a_copy_of_it_was
      chunks = []
      misread = misreading do |response|
        response.clone.read_body { |chunk| chunks << chunk }
        response.read_body { |chunk| chunks << chunk }
      end

      assert_equal [[Error, READ_ONCE, 1], ["{}"]], [misread, chunks]
    end

    def test_a_copy_returns_the_body_the_response_read_whole
      assert_equal %w[{} {}], reading { |response| [response.read_body, response.dup.read_body] }
    end

    private

    # Yield the response of a stream a server on the loopback interface answers
    def reading(&)
      with_local_connections([WHOLE]) { |port, _requests| client(port).get_stream("stream", &) }
    end

    # Freeze a response with what it holds, as Ractor.make_shareable froze one before Ruby 4.1, which refuses to
    # share the socket of one, and so raises, having frozen some of it
    def deeply_freeze(response) = response.instance_variables.each { |name| response.instance_variable_get(name).freeze }.then { response.freeze }

    # What the block returns for the response of a stream frozen deeply, once its body was read whole if read is
    # true; Net::HTTP cannot close the response that was frozen with it, so get_stream raises a FrozenError for it
    def deep_frozen(read: false)
      result = nil
      assert_raises(FrozenError) do
        reading do |response|
          response.read_body if read
          result = yield deeply_freeze(response)
        end
      end
      result
    end

    # The class and message of the Error raised by the block, or by a read of the body of what the block returns once
    # get_stream has returned, inside with_retries, and the number of requests the server was sent
    def misreading(&block)
      with_local_connections(*[[WHOLE]] * 3) do |port, requests|
        client = client(port)
        error = assert_raises(Error) { client.with_retries { client.get_stream("stream", &block).read_body } }

        [error.class, error.message, requests.size]
      end
    end

    # A client of the server on the port, which sends a request again twice
    def client(port) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", max_retries: 2)
  end
end
