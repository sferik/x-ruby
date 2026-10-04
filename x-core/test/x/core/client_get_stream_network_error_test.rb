# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The read_body of the response a GET request passes its block raises a NetworkError for an error of the socket,
  # inside the block, which rescues it with no class of the transport, and get_stream raises it as it is
  class ClientGetStreamNetworkErrorTest < Minitest::Test
    include LocalServer

    cover_client
    cover StreamResponse
    cover Core.const_get(:StreamBody)

    # A response whose connection drops partway through its body
    TRUNCATED = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"
    # A response whose body ends
    WHOLE = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}"

    def test_a_body_that_drops_is_rescued_as_a_network_error_inside_the_block
      streaming_locally(TRUNCATED) do |client|
        chunks = []
        rescued = client.get_stream("stream") do |response|
          response.read_body { |chunk| chunks << chunk }
        rescue NetworkError => e
          e
        end

        assert_equal [NetworkError, ["{\"data\":"]], [rescued.class, chunks]
      end
    end

    def test_a_body_that_drops_while_it_is_read_whole_is_rescued_as_a_network_error_inside_the_block
      streaming_locally(TRUNCATED) do |client|
        rescued = client.get_stream("stream") do |response|
          response.read_body
        rescue NetworkError => e
          e
        end

        assert_instance_of NetworkError, rescued
      end
    end

    def test_a_read_that_times_out_is_rescued_as_a_network_error_inside_the_block
      stalling_locally do |client|
        rescued = client.get_stream("stream") do |response|
          response.read_body { |_chunk| }
        rescue NetworkError => e
          e
        end

        assert_equal [NetworkError, Net::ReadTimeout], [rescued.class, rescued.cause.class]
      end
    end

    def test_the_network_error_names_the_request_and_its_cause_is_the_error_of_the_socket
      streaming_locally(TRUNCATED) do |client|
        error = assert_raises(NetworkError) { client.get_stream("stream?expansions=author_id") { |response| response.read_body { |_chunk| } } }

        assert_instance_of EOFError, error.cause
        assert_equal "GET /2/stream: Network error: #{error.cause.message}", error.message
        assert_equal [:get, URI("#{client.base_url}stream?expansions=author_id")], [error.http_method, error.uri]
      end
    end

    def test_the_network_error_read_body_raises_is_raised_from_get_stream_as_it_is
      streaming_locally(TRUNCATED) do |client|
        raised = []
        error = assert_raises(NetworkError) { client.get_stream("stream") { |response| reraising(raised) { response.read_body { |_chunk| } } } }

        assert_equal [[error], EOFError], [raised, error.cause.class]
        assert_same raised.first, error
      end
    end

    def test_a_body_that_drops_while_another_thread_reads_it_is_a_network_error
      streaming_locally(TRUNCATED) do |client|
        error = assert_raises(NetworkError) do
          client.get_stream("stream") { |response| Thread.new { response.read_body { |_chunk| } }.tap { |thread| thread.report_on_exception = false }.value }
        end

        assert_instance_of EOFError, error.cause
      end
    end

    # The error is the stream's own, rather than a callback's, so with_retries opens the stream again after it
    def test_a_body_that_drops_is_read_again_by_with_retries
      with_local_connections([TRUNCATED], [WHOLE]) do |port, requests|
        client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/")
        handler = internals(client).instance_variable_get(:@retry_handler)

        assert_equal "{}", handler.stub(:sleep, nil) { client.with_retries { client.get_stream("stream", &:read_body) } }
        assert_equal 2, requests.size
      end
    end

    private

    # Run the block, adding the NetworkError it raises to raised before it is raised again
    def reraising(raised)
      yield
    rescue NetworkError => e
      raised << e
      raise
    end

    # Stream from a server on the loopback interface with WebMock out of the way, which would read the body whole
    # before the block were passed the response
    def streaming_locally(response)
      WebMock.disable!
      with_local_server(response:) { |port| yield Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/") }
    ensure
      WebMock.enable!
    end

    # Stream from a server that sends the start of a body and then nothing, with a client that waits a moment for more
    def stalling_locally
      server = TCPServer.new("127.0.0.1", 0)
      thread = Thread.new { server.accept.tap { |socket| socket.gets("\r\n\r\n") }.write(TRUNCATED) && sleep }
      WebMock.disable!
      yield Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{server.addr[1]}/2/", read_timeout: 0.05)
    ensure
      WebMock.enable!
      thread&.kill
      server&.close
    end
  end
end
