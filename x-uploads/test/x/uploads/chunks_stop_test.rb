# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/chunks"

module X
  # A worker stopped outside a request, as it records the failure of a chunk, ends as one stopped mid-request does, and
  # one stopped as it reads a chunk reads it first, so that the file it reads is closed
  class ChunksStopTest < Minitest::Test
    cover Uploads.const_get(:Chunks)

    # A client whose every request fails
    class FailingClient
      def post(*, **) = raise(BadRequest, "refused")
    end

    # Errors that never take the one a worker records, telling when the worker began to record it
    class StuckErrors
      def initialize(recording) = @recording = recording

      def <<(_error) = @recording << true && sleep
    end

    # A client whose requests run a callback that rescues every StandardError, as an on_response may, telling when one
    # began and counting those that ended
    class RescuingClient
      attr_reader :ended

      def initialize(began)
        @began = began
        @ended = 0
      end

      def post(*, **)
        @began << true
        begin
          sleep 0.5
        rescue
          nil
        end
        @ended += 1
      end
    end

    # Media whose every read takes a moment, telling when one began and counting those that ended
    class SlowSource
      attr_reader :ended

      def initialize(began)
        @began = began
        @ended = 0
      end

      def size = 1024

      def read(length, _offset)
        @began << true
        sleep 0.1
        @ended += 1
        "\x01".b * length
      end
    end

    def setup
      @dir = Dir.mktmpdir
      @path = File.join(@dir, "video.mp4")
      File.binwrite(@path, "\x01".b * 1024)
    end

    def teardown
      FileUtils.remove_entry(@dir)
    end

    def test_a_worker_stopped_as_it_records_a_failure_ends_without_raising
      recording = Thread::Queue.new
      worker = start(StuckErrors.new(recording))
      recording.pop
      worker.raise(Uploads.const_get(:Chunks).const_get(:Stopped))

      assert_nil worker.value
    end

    def test_a_worker_stopped_in_a_callback_that_rescues_every_standard_error_ends_at_once
      began = Thread::Queue.new
      client = RescuingClient.new(began)
      worker = start(Thread::Queue.new, client:, chunks: 3)
      began.pop
      worker.raise(Uploads.const_get(:Chunks).const_get(:Stopped))

      refute_nil worker.join(0.4)
      assert_equal 0, client.ended
    end

    def test_a_worker_stopped_as_it_reads_a_chunk_reads_it_before_it_ends_and_sends_nothing
      began = Thread::Queue.new
      source = SlowSource.new(began)
      errors = Thread::Queue.new
      worker = start(errors, source:)
      began.pop(timeout: 5)
      worker.raise(Uploads.const_get(:Chunks).const_get(:Stopped))

      assert_equal [nil, 1, 0], [worker.value, source.ended, errors.size]
    end

    private

    def start(errors, client: FailingClient.new, chunks: 1, source: Uploads.const_get(:Source).for(@path))
      queue = Queue.new.tap { |queued| chunks.times { |index| queued << [index, 0] } }.close
      Uploads.const_get(:Chunks).__send__(:append_worker, queue, errors, client:, source:, chunk_size: 1024, media_id: "1", boundary: "b")
    end
  end
end
