# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/chunks"

module X
  # A worker that cannot be started stops the workers started before it, as an exception raised in the caller does
  class ChunksStartFailureTest < Minitest::Test
    cover Uploads.const_get(:Chunks)

    CHUNK_BYTES = 1024

    # A client whose requests never return
    class StalledClient
      def post(*, **) = sleep
    end

    def setup
      @dir = Dir.mktmpdir
      @path = File.join(@dir, "video.mp4")
      File.binwrite(@path, "\x01".b * (6 * CHUNK_BYTES))
      @started = []
    end

    # Every worker has been stopped by now, and one stopped as it reads a chunk closes the file once it has read it, so
    # each is waited for, and killed only if it does not end, before the file is deleted, which Windows refuses to do
    # while a worker holds it open
    def teardown
      @started.each { |thread| thread.join(1) || thread.kill.join }
      FileUtils.remove_entry(@dir)
    end

    def test_a_worker_that_cannot_be_started_stops_the_workers_started_before_it
      error = refusing_the_third_thread { assert_raises(ThreadError) { append } }

      assert_equal "can't create Thread: Resource temporarily unavailable", error.message
      assert_equal [false, false], @started.map(&:alive?)
    end

    private

    # Run a block in which the third thread started raises ThreadError, as a system out of threads refuses one
    def refusing_the_third_thread(&)
      start = Thread.method(:new)
      refuse = lambda do |*args, &block|
        raise ThreadError, "can't create Thread: Resource temporarily unavailable" if @started.size.eql?(2)

        start.call(*args, &block).tap { |thread| @started << thread }
      end
      Thread.stub(:new, refuse, &)
    end

    # Upload the chunks of the media, three at a time, which never finishes, since the client never answers
    def append
      Uploads.const_get(:Chunks).append(client: StalledClient.new, source: Uploads.const_get(:Source).for(@path),
        chunk_size: CHUNK_BYTES, media: {"id" => "1"}, boundary: "b", concurrency: 3)
    end
  end
end
