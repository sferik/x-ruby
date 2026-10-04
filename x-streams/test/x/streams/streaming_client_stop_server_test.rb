# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream is stopped as it reads from a socket of a server on the loopback interface, which holds the stream open and
  # sends nothing, from another thread or from the trap of a signal, a stream a stopped streaming client is asked to run
  # never connects, and an on_response the server's failed response is passed runs to its end
  class StreamingClientStopServerTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:Stopper)

    # The head of a stream, whose body the server never sends
    HEAD = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n"
    # A failed response, which a stream reconnects after
    UNAVAILABLE = "HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"

    def setup
      @server = TCPServer.new("127.0.0.1", 0)
      @sockets, @threads, @opened, @response = Queue.new, [], Queue.new, HEAD
      @started, @resume = Queue.new, Queue.new
      @threads << Thread.new { loop { serve(@server.accept) } }
      @streaming = client.streaming
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

    def test_a_stream_waiting_on_a_read_is_stopped_at_once_from_the_trap_of_a_signal
      trapping("USR2", -> { @streaming.stop }) do
        signal_once_waiting("USR2", Thread.current)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        assert_nil @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" }
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
      end
    end

    def test_a_stream_in_another_thread_is_stopped_from_the_trap_of_a_signal
      reader = start { @streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      trapping("USR2", -> { @streaming.stop }) do
        @opened.pop
        Process.kill("USR2", Process.pid)

        assert_nil reader.join(5)&.value
      end
    end

    def test_an_on_response_that_runs_for_a_failed_response_when_the_stream_is_stopped_runs_to_its_end
      @response, finished = UNAVAILABLE, []
      streaming = client(on_response: pausing { |response| finished << response.status }).streaming
      reader = start { streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      stop_while_paused(streaming)

      assert_equal [nil, [503]], [reader.join(5)&.value, finished]
    end

    private

    # A callable that says it started, waits to be resumed, and passes what it was passed to the block given
    def pausing(&finish) = ->(object) { (@started << true) && @resume.pop && finish.call(object) }

    # Stop a streaming client while the callable that pauses it runs, and resume it
    def stop_while_paused(streaming)
      @started.pop
      streaming.stop
      @resume << true
    end

    # A client of the server
    def client(**) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{@server.addr[1]}/2/", **)

    # Answer a request with the response of the test, the head of a stream unless it says otherwise, and hold its socket
    # open, sending nothing more
    def serve(socket)
      @sockets << socket
      socket.gets("\r\n\r\n")
      socket.write(@response)
      @opened << true
    end

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end

    # Send a signal to the process once the stream opened and the thread that reads it waits on the read
    def signal_once_waiting(signal, reader)
      start do
        @opened.pop
        Thread.pass until reader.status.eql?("sleep")
        sleep 0.1
        Process.kill(signal, Process.pid)
      end
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
