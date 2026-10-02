# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream is stopped as it reads from a socket of a server on the loopback interface, which holds the stream open and
  # sends nothing, from another thread or from the trap of a signal, and a stream a stopped streaming client is asked to
  # run never connects
  class StreamingClientStopServerTest < Minitest::Test
    cover StreamingClient
    cover Streaming.const_get(:Stopper)

    # The head of a stream, whose body the server never sends
    HEAD = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n"

    def setup
      @server = TCPServer.new("127.0.0.1", 0)
      @sockets, @threads, @opened = Queue.new, [], Queue.new
      @threads << Thread.new { loop { serve(@server.accept) } }
      @streaming = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{@server.addr[1]}/2/").streaming
      WebMock.disable!
    end

    def teardown
      WebMock.enable!
      @threads.each(&:kill)
      @sockets.close.size.times { @sockets.pop.close }
      @server.close
    end

    def test_a_stream_that_reads_from_a_socket_is_stopped_from_another_thread
      reader = start { @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      @opened.pop

      assert_nil @streaming.stop
      assert_nil reader.join(5)&.value
      assert_predicate reader, :stop?
    end

    def test_a_stream_a_thread_runs_after_the_streaming_client_was_stopped_returns_nil_without_connecting
      @streaming.stop
      reader = start { @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }

      assert_nil reader.join(5)&.value
      assert_predicate reader, :stop?
      assert_empty @sockets
    end

    def test_a_stream_is_stopped_from_the_trap_of_a_signal
      stopped = Queue.new
      trapping("USR2", -> { stopped << @streaming.stop }) do
        start { @opened.pop && Process.kill("USR2", Process.pid) }

        assert_nil @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" }
      end

      assert_nil stopped.pop(timeout: 5)
    end

    def test_a_stream_in_another_thread_is_stopped_from_the_trap_of_a_signal
      reader = start { @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      trapping("USR2", -> { @streaming.stop }) do
        @opened.pop
        Process.kill("USR2", Process.pid)

        assert_nil reader.join(5)&.value
      end
    end

    private

    # Answer a request with the head of a stream, and hold its socket open, sending nothing more
    def serve(socket)
      @sockets << socket
      socket.gets("\r\n\r\n")
      socket.write(HEAD)
      @opened << true
    end

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end

    # Run a block with a signal trapped by a callable, and the trap the signal had restored after, or skip the test on
    # a platform without the signal
    def trapping(signal, handler)
      skip "this platform has no SIG#{signal}" unless Signal.list.key?(signal)
      previous = Signal.trap(signal) { handler.call }
      begin
        yield
      ensure
        Signal.trap(signal, previous)
      end
    end
  end
end
