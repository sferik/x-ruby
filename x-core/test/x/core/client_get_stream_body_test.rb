# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The body of a GET request the block reads raises a NetworkError for an error read_body raises from the socket, and
  # raises any error of what the block passes the body to as it was, whatever its class
  class ClientGetStreamBodyTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
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

    def test_a_body_that_drops_while_it_is_read_whole_is_a_network_error
      streaming_locally(TRUNCATED) do |client|
        assert_raises(NetworkError) { client.get_stream("stream", &:read_body) }
      end
    end

    # The response of the transport is an escape hatch, which notes no error of the socket, so the error is the block's
    def test_a_body_that_drops_while_it_is_read_from_the_http_response_raises_the_error_of_the_socket_as_the_blocks_own
      streaming_locally(TRUNCATED) do |client|
        error = assert_raises(StandardError) { client.get_stream("stream") { |response| response.http_response.read_body { |_chunk| } } }

        refute_kind_of NetworkError, error
      end
    end

    def test_an_error_of_a_socket_the_block_passed_each_chunk_raises_is_raised_as_it_was
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      full = Errno::ENOSPC.new("the disk is full")

      assert_same full, assert_raises(Errno::ENOSPC) { @client.get_stream("tweets/sample/stream") { |response| response.read_body { |_chunk| raise full } } }
    end

    def test_a_body_read_through_a_block_passes_each_chunk_to_it_and_returns_nil
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      chunks = []
      body = @client.get_stream("tweets/sample/stream") { |response| [response.read_body { |chunk| chunks << chunk }] }

      assert_equal [["{}"], [nil]], [chunks, body]
    end

    def test_a_body_read_whole_is_the_body
      stub_request(:get, STREAM_URL).to_return(body: "{}")

      assert_equal "{}", @client.get_stream("tweets/sample/stream", &:read_body)
    end

    # An error is the socket's by its class as well as by where it was raised, so one that is not an error of a
    # network, which the transport raised of its own while the body was read, is raised as it was
    def test_an_error_read_body_raises_that_is_not_one_of_a_network_is_raised_as_it_was
      stub_request(:get, STREAM_URL).to_return(body: "{}")
      misread = ArgumentError.new("the body could not be read")
      error = assert_raises(ArgumentError) do
        @client.get_stream("tweets/sample/stream") do |response|
          response.http_response.define_singleton_method(:read_body) { |&_block| raise misread }
          response.read_body { |_chunk| }
        end
      end

      assert_same misread, error
    end

    def test_an_error_read_body_did_not_raise_for_the_socket_is_not_the_sockets
      assert_equal [false, false], [Core.const_get(:StreamBody).socket_error?(IOError.new), Core.const_get(:StreamBody).socket_error?(NetworkError.new)]
    end

    def test_a_network_error_the_block_raises_of_its_own_is_raised_as_it_was_and_not_read_again
      stub_request(:get, STREAM_URL)
      failed = NetworkError.new("Network error: another request failed")

      assert_same failed, assert_raises(NetworkError) { @client.with_retries { @client.get_stream("tweets/sample/stream") { |_response| raise failed } } }
      assert_requested :get, STREAM_URL, times: 1
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
