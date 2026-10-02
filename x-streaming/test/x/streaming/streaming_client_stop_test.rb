# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream that delivers nothing is stopped from another thread with stop, which the stream returns nil for
  class StreamingClientStopTest < Minitest::Test
    cover StreamingClient

    POST = "{\"data\":{\"id\":\"1\"}}\r\n"

    def setup
      @streaming = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
      @readers = []
      @started, @resume, @finished = Queue.new, Queue.new, Queue.new
    end

    def teardown
      @readers.each(&:kill)
    end

    def test_a_stream_that_delivers_nothing_is_stopped_from_another_thread
      reader = read_in_thread([]) { |_post| flunk "unexpected yield" }
      waiting = wait_for(reader)

      assert_equal 1, @streaming.stop
      assert_nil reader.value
      assert waiting
    end

    def test_stop_stops_nothing_when_no_stream_runs
      assert_equal 0, @streaming.stop
    end

    def test_stop_stops_every_stream_of_the_streaming_client_and_no_other
      other = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
      readers = Array.new(2) { read_in_thread([]) { |_post| nil } }
      unstopped = read_in_thread([], streaming: other) { |_post| nil }
      [*readers, unstopped].each { |reader| wait_for(reader) }

      assert_equal 2, @streaming.stop
      assert_equal [nil, nil], readers.map(&:value)
      assert_equal "sleep", unstopped.status
    end

    def test_a_block_that_runs_when_the_stream_is_stopped_runs_to_its_end
      reader = read_in_thread([POST], &pausing)

      assert_nil stopping_while_paused(reader)
      assert_equal 1, @finished.size
    end

    def test_an_on_response_that_runs_when_the_stream_is_stopped_runs_to_its_end
      @streaming = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: pausing).streaming
      reader = read_in_thread([POST]) { |_post| nil }

      assert_nil stopping_while_paused(reader)
      assert_equal 1, @finished.size
    end

    def test_a_stream_stopped_from_its_own_block_stops_once_the_block_returns
      delivered = []
      result = stubbing_the_stream([POST, POST]) { @streaming.stream("tweets/sample/stream") { |post| delivered << post && @streaming.stop } }

      assert_nil result
      assert_equal 2, delivered.size
    end

    def test_a_stream_opened_after_a_stop_runs
      wait_for(read_in_thread([]) { |_post| nil })
      @streaming.stop
      result = stubbing_the_stream([POST]) { @streaming.stream("tweets/sample/stream") { |post| break post } }

      assert_equal({"data" => {"id" => "1"}}, result)
    end

    private

    # A callable that says it started, waits to be resumed, and says it finished
    def pausing = ->(_object) { (@started << true) && @resume.pop && (@finished << true) }

    # Stop the stream of a reader while the callable that pauses it runs, resume it, and return what the stream returned
    def stopping_while_paused(reader)
      @started.pop
      @streaming.stop
      @resume << true
      reader.value
    end

    # Open a stream in a thread of its own, whose body delivers the chunks given and then waits on the API for good
    def read_in_thread(chunks, streaming: @streaming, &block)
      opened = answering(streaming, chunks)
      reader = Thread.new { streaming.stream("tweets/sample/stream", &block) }
      reader.report_on_exception = false
      @readers << reader
      opened.pop(timeout: 1)
      reader
    end

    # Answer the streams of a streaming client with a body that delivers the chunks given, and then waits
    def stubbing_the_stream(chunks)
      answering(@streaming, chunks)
      yield
    end

    # Answer each stream of a streaming client with a body that delivers the chunks given, and then waits on the API
    # for good, as a stream that delivers nothing more does, returning the queue each stream that waits is told on
    def answering(streaming, chunks)
      opened, respond = Queue.new, method(:waiting_response)
      streaming.instance_variable_get(:@stream_client).define_singleton_method(:get_stream) do |endpoint, **, &block|
        block.call(respond.call(URI.join("https://api.x.com/2/", endpoint), chunks, opened))
      end
      opened
    end

    # A successful response whose body delivers the chunks given, tells the queue given, and then waits for good
    def waiting_response(uri, chunks, opened)
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.uri = uri
        response.define_singleton_method(:read_body) do |&read|
          chunks.each { |chunk| read.call(chunk) }
          opened << true
          sleep
        end
      end
    end

    # Wait until a thread waits, whether on the API or on a lock, true once it does, or false if it ended
    def wait_for(thread)
      Thread.pass until thread.status.eql?("sleep") || !thread.alive?
      thread.alive?
    end
  end
end
