# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/chunks"

module X
  # An exception raised in the caller as a worker is started, or as the workers are stopped, stops every worker still
  class ChunksInterruptWindowTest < Minitest::Test
    cover Uploads.const_get(:Chunks)

    CHUNK_BYTES = 1024

    # An exception raised in the caller, as an interrupt or a timeout is
    class Interrupted < StandardError; end

    # A client whose requests never return
    class StalledClient
      def post(*, **) = sleep
    end

    # A client whose requests each take a moment, counting those begun
    class CountingClient
      attr_reader :posts

      def initialize = @posts = Queue.new

      def post(*, **) = (@posts << true) && sleep(0.05)
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

    def test_an_exception_raised_in_the_caller_as_a_worker_is_started_stops_that_worker_too
      start = Thread.method(:new)
      interrupting = lambda do |*args, &block|
        start.call(*args, &block).tap { |thread| (@started << thread) && Thread.current.raise(Interrupted) }
      end
      assert_raises(Interrupted) { Thread.stub(:new, interrupting) { append } }

      assert_equal [false], @started.map { |thread| thread.join(1) && thread.alive? }
    end

    def test_an_exception_raised_in_the_caller_as_the_workers_are_stopped_stops_every_worker
      start = Thread.method(:new)
      caller = Thread.current
      start.call { interrupting_once_started(caller) }
      assert_raises(Interrupted) { Thread.stub(:new, tracking(start)) { append } }

      assert_equal [false] * 3, @started.map { |thread| thread.join(1) && thread.alive? }
    end

    def test_an_exception_a_trap_raises_as_a_worker_is_started_leaves_it_no_chunk_to_begin
      client = CountingClient.new
      assert_raises(Interrupted) { Thread.stub(:new, raising_at_the_second) { append(client) } }
      @started.each { |thread| thread.join(1) }

      assert_operator client.posts.size, :<=, 2
    end

    private

    # Make a stop of a worker raise an exception in the caller as well, as a second interrupt that lands then would
    def interrupt_as_stopped(worker, caller)
      worker.define_singleton_method(:raise) do |*arguments|
        caller.raise(Interrupted)
        super(*arguments)
      end
    end

    # Start a thread as Thread.new does, keeping it to be told whether it is still alive
    def tracking(start) = ->(*args, &block) { start.call(*args, &block).tap { |thread| @started << thread } }

    # Raise an exception in the caller once three workers are started, and again as the first is stopped
    def interrupting_once_started(caller)
      Thread.pass until @started.size.eql?(3)
      interrupt_as_stopped(@started.first, caller)
      caller.raise(Interrupted)
    end

    # Start threads as Thread.new does, raising in it once the second is started, as a trap that raises does
    def raising_at_the_second
      start = Thread.method(:new)
      ->(*args, &block) { start.call(*args, &block).tap { |thread| (@started << thread).size.eql?(2) && raise(Interrupted) } }
    end

    def append(client = StalledClient.new)
      Uploads.const_get(:Chunks).append(client:, source: Uploads.const_get(:Source).for(@path),
        chunk_size: CHUNK_BYTES, media: {"id" => "1"}, boundary: "b", concurrency: 3)
    end
  end
end
