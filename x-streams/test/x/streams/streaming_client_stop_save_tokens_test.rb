# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stop that lands while the save_tokens of a refresh the stream made is storing the tokens waits for it to store
  # them, and the stream then returns nil, so the store never holds a refresh token X no longer accepts
  class StreamingClientStopSaveTokensTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:Stopper)

    TOKENS = %({"token_type":"bearer","access_token":"acc-1","refresh_token":"ref-1","expires_in":7200})

    def setup
      @server = TCPServer.new("127.0.0.1", 0)
      @thread = Thread.new { loop { Thread.new(@server.accept) { |socket| serve(socket) } } }
      WebMock.disable!
    end

    def teardown
      WebMock.enable!
      @thread.kill
      @server.close
    end

    def test_a_stop_during_save_tokens_waits_for_it_and_the_stream_returns_nil
      saving, stored = Queue.new, []
      streaming = client(lambda do |tokens|
        saving << true
        sleep 0.3
        stored << tokens.refresh_token
      end).streaming
      reader = Thread.new { streaming.stream("tweets/search/stream") { |_post| nil } }
      saving.pop(timeout: 5)
      streaming.stop

      assert_equal [nil, ["ref-1"]], [reader.join(5)&.value, stored]
    end

    def test_a_stream_sets_the_guard_of_the_fiber_back_as_it_was
      outer = -> {}
      Thread.current[:x_core_refresh_report_guard] = outer
      streaming = client(->(_tokens) {}).streaming
      stopping(streaming)
      streaming.stream("tweets/search/stream") { |_post| nil }

      assert_same outer, Thread.current[:x_core_refresh_report_guard]
    ensure
      Thread.current[:x_core_refresh_report_guard] = nil
    end

    private

    def stopping(streaming)
      Thread.new do
        sleep 0.2
        streaming.stop
      end
    end

    def client(save_tokens)
      Client.new(client_id: "cid", access_token: "acc-0", refresh_token: "ref-0", expires_at: Time.now - 1,
        base_url: "http://127.0.0.1:#{@server.addr[1]}/2/", save_tokens:)
    end

    def serve(socket)
      request = socket.gets.to_s
      socket.read(content_length(socket))
      request.include?("/oauth2/token") ? answer(socket, TOKENS) : hold_open(socket)
    rescue IOError, SystemCallError
      nil
    ensure
      socket.close
    end

    def content_length(socket)
      length = 0
      while (line = socket.gets) && line != "\r\n"
        length = line.split(":", 2).last.to_i if line.downcase.start_with?("content-length")
      end
      length
    end

    def answer(socket, body) = socket.write("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: #{body.bytesize}\r\n\r\n#{body}")

    def hold_open(socket)
      socket.write("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n")
      loop do
        socket.write("\r\n")
        sleep 0.1
      end
    end
  end
end
