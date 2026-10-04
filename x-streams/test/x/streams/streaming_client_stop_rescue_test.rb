# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream stopped as the object_class builds an object, in a lookup whose errors it rescues, returns nil rather than
  # raise the error the object_class raises in turn
  class StreamingClientStopRescueTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    # The head of a stream and one post of it, after which the server sends nothing
    RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n" \
      "#{(line = "#{{data: {id: "1", text: "hi"}}.to_json}\r\n").bytesize.to_s(16)}\r\n#{line}\r\n"

    # An object_class whose from_response looks something up, raising an error of its own for any error of the lookup
    class Looking
      BUILDING = Thread::Queue.new

      def self.from_response(_attributes, **)
        BUILDING << true
        sleep 5
      rescue
        raise ArgumentError, "the lookup failed"
      end
    end

    def setup
      @server = TCPServer.new("127.0.0.1", 0)
      @accepting = Thread.new { loop { serve(@server.accept) } }
      @sockets = []
      WebMock.disable!
    end

    def teardown
      WebMock.enable!
      @accepting.kill
      @sockets.each(&:close)
      @server.close
    end

    def test_a_stream_stopped_in_an_object_class_that_rescues_every_standard_error_returns_nil
      streaming = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{@server.addr[1]}/2/").streaming
      reader = Thread.new { streaming.stream("tweets/sample/stream", object_class: Looking) { |_post| flunk "unexpected yield" } }
      reader.report_on_exception = false
      Looking::BUILDING.pop(timeout: 5)
      streaming.stop

      assert_nil reader.join(5)&.value
      assert_predicate reader, :stop?
    end

    private

    def serve(socket)
      @sockets << socket
      socket.gets("\r\n\r\n")
      socket.write(RESPONSE)
    end
  end
end
