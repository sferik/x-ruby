require "fileutils"
require "timeout"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/chunks"

module X
  class ChunksInterruptTest < Minitest::Test
    cover Uploader::Chunks

    CHUNK_BYTES = 1024

    # A client whose requests never return, and take a moment to clean up after themselves once they are killed
    class StalledClient
      attr_reader :started, :cleaned_up

      def initialize
        @started = Queue.new
        @cleaned_up = Queue.new
      end

      def post(*, **)
        @started << Thread.current
        sleep
      ensure
        sleep 0.02
        @cleaned_up << Thread.current
      end
    end

    def setup
      @dir = Dir.mktmpdir
      @path = File.join(@dir, "video.mp4")
      File.binwrite(@path, "\x01".b * (6 * CHUNK_BYTES))
      @client = StalledClient.new
      @uploader = Thread.new { Uploader::Chunks.append(client: @client, file_path: @path, chunk_size: CHUNK_BYTES, media: {"id" => "1"}, boundary: "b", concurrency: 2) }
      @uploader.report_on_exception = false
      @workers = Array.new(2) { @client.started.pop(timeout: 1) }
    end

    def teardown
      [@uploader, *@workers].compact.each(&:kill)
      FileUtils.remove_entry(@dir)
    end

    def test_an_exception_raised_in_the_caller_reaches_it_without_waiting_for_the_chunks
      assert_kind_of Timeout::Error, interrupt
    end

    def test_an_exception_raised_in_the_caller_stops_the_chunks_already_begun
      interrupt

      assert_equal 2, @client.cleaned_up.size
      assert_equal [false, false], @workers.map(&:alive?)
    end

    def test_an_exception_raised_in_the_caller_stops_the_chunks_not_yet_begun
      interrupt

      assert_empty @client.started
    end

    private

    # Interrupt the upload as a timeout would, and return the exception once the upload has ended
    def interrupt
      @uploader.raise(Timeout::Error)
      assert_raises(Timeout::Error) { assert @uploader.join(1), "Expected the timeout to end the upload" }
    end
  end
end
