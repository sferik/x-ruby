# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a GET request the block reads raises a NetworkError for an error read_body raises from the socket, and
  # raises any error of what the block passes the body to as it was, whatever its class
  class ClientGetStreamBodyTest < Minitest::Test
    include LocalServer

    cover_client
    cover Core.const_get(:StreamBody)

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    # A response whose connection drops partway through its body
    TRUNCATED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_a_body_that_drops_while_its_chunks_are_read_is_a_network_error
      streaming_locally(TRUNCATED) do |client|
        assert_raises(NetworkError) { client.get_stream("stream") { |response| response.read_body { |_chunk| } } }
      end
    end

    def test_a_body_that_drops_while_it_is_read_into_dest_is_a_network_error
      streaming_locally(TRUNCATED) do |client|
        assert_raises(NetworkError) { client.get_stream("stream") { |response| response.read_body(+"") } }
      end
    end

    def test_a_body_that_drops_while_it_is_read_whole_is_a_network_error
      streaming_locally(TRUNCATED) do |client|
        assert_raises(NetworkError) { client.get_stream("stream", &:body) }
      end
    end

    def test_an_error_of_a_socket_the_block_passed_each_chunk_raises_is_raised_as_it_was
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      full = Errno::ENOSPC.new("the disk is full")

      assert_same full, assert_raises(Errno::ENOSPC) { @client.get_stream("tweets/sample/stream") { |response| response.read_body { |_chunk| raise full } } }
    end

    def test_an_error_of_a_socket_dest_raises_is_raised_as_it_was
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      dest = Object.new.tap { |full| full.define_singleton_method(:<<) { |_chunk| raise IOError, "the file closed" } }

      assert_equal "the file closed", assert_raises(IOError) { @client.get_stream("tweets/sample/stream") { |response| response.read_body(dest) } }.message
    end

    def test_a_body_read_into_dest_returns_dest_holding_the_body
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      dest = +""

      assert_same dest, @client.get_stream("tweets/sample/stream") { |response| response.read_body(dest) }
      assert_equal "{}", dest
    end

    def test_a_body_read_through_a_block_passes_each_chunk_to_it
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      chunks = []
      body = @client.get_stream("tweets/sample/stream") { |response| response.read_body { |chunk| chunks << chunk } }

      assert_equal ["{}"], chunks
      assert_instance_of Net::ReadAdapter, body
    end

    def test_a_body_read_whole_is_the_body
      stub_request(:get, STREAM_URL).to_return(body: "{}")

      assert_equal %w[{} {}], @client.get_stream("tweets/sample/stream") { |response| [response.read_body, response.body] }
    end

    def test_a_body_read_into_dest_and_a_block_raises_as_read_body_does_as_the_blocks_own
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      error = assert_raises(ArgumentError) { @client.get_stream("tweets/sample/stream") { |response| response.read_body(+"") { |_chunk| } } }

      assert Core.const_get(:CallbackError).untagged?(error)
    end

    def test_an_error_read_body_did_not_raise_from_the_socket_is_not_the_sockets
      assert_equal [false, false], [Core.const_get(:StreamBody).socket_error?(IOError.new), Core.const_get(:StreamBody).socket_error?(ArgumentError.new)]
    end

    private

    # Stream from a server on the loopback interface with WebMock out of the way, which would read the body whole
    # before the block were passed the response
    def streaming_locally(response)
      WebMock.disable!
      with_local_server(response:) { |port| yield Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/") }
    ensure
      WebMock.enable!
    end
  end
end
