# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stop raises in the streams under the lock if it takes the lock at once, and otherwise hands that to a thread of
  # its own, which it does not wait for, as in the trap of a signal, where no lock can be waited for
  class StopperLockTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    STOPPER = Streams.const_get(:Stopper)

    def setup
      @stopper = STOPPER.new
      @lock = @stopper.instance_variable_get(:@lock)
      @threads = []
    end

    def teardown
      @lock.unlock if @lock.owned?
      @threads.each(&:kill)
    end

    def test_stop_raises_in_the_streams_itself_where_the_lock_is_free
      runner = sleeping_run
      Thread.stub(:new, ->(*) { flunk "unexpected thread" }) { @stopper.stop }

      assert_nil runner.value
    end

    def test_stop_in_a_stream_that_reads_beside_another_stops_both_from_a_thread_of_its_own
      other, helpers = sleeping_run, []
      returned = @stopper.run do
        Thread.stub(:new, ->(*, &block) { (helpers << true) && Thread.start(&block) }) { @stopper.stop }
        sleep
      end

      assert_equal [nil, nil, [true]], [returned, other.value, helpers]
    end

    def test_a_stream_that_ends_leaves_the_others_the_stopper_runs_known_to_stop
      other = sleeping_run
      @stopper.run { :done }
      @stopper.stop

      assert_nil other.join(5).value
    end

    def test_stop_returns_without_waiting_for_the_lock_and_stops_the_streams_once_it_is_free
      ended = Queue.new
      runner = sleeping_run { ended << true }
      @lock.lock

      assert_nil @stopper.stop
      assert_nil ended.pop(timeout: 0.5)
      @lock.unlock

      assert_nil runner.value
    end

    def test_stop_where_the_lock_cannot_be_taken_stops_the_streams_from_a_thread_of_its_own
      runner = sleeping_run
      @lock.stub(:try_lock, -> { raise ThreadError, "can't be called from trap context" }) { @stopper.stop }

      assert_nil runner.value
    end

    private

    # A thread whose run waits on nothing but a stop, and calls the block given, if any, as it ends
    def sleeping_run(&ended)
      runner = start do
        @stopper.run do
          sleep
        ensure
          ended&.call
        end
      end
      runner.tap { Thread.pass until runner.status.eql?("sleep") }
    end

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end
  end
end
