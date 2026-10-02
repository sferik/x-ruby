# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stop raises in the streams under the lock if it takes the lock at once, and otherwise hands that to a thread of
  # its own, which it does not wait for, as in the trap of a signal, where no lock can be waited for
  class StopperLockTest < Minitest::Test
    cover Streaming.const_get(:Stopper)

    STOPPER = Streaming.const_get(:Stopper)

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

    def test_stop_returns_without_waiting_for_the_lock_and_stops_the_streams_once_it_is_free
      runner, resume = guarded_run
      @lock.lock

      assert_nil @stopper.stop
      sleep 0.1

      refute_predicate runner, :pending_interrupt?
      @lock.unlock
      resume << true

      assert_nil runner.value
    end

    def test_stop_where_the_lock_cannot_be_taken_stops_the_streams_from_a_thread_of_its_own
      runner = sleeping_run
      @lock.stub(:try_lock, -> { raise ThreadError, "can't be called from trap context" }) { @stopper.stop }

      assert_nil runner.value
    end

    private

    # A thread whose run waits on nothing but a stop
    def sleeping_run
      start { @stopper.run { sleep } }.tap { |runner| Thread.pass until runner.status.eql?("sleep") }
    end

    # A thread whose run is in a guarded block, which holds a stop back until the queue returned beside it is told
    def guarded_run
      started, resume = Queue.new, Queue.new
      runner = start { @stopper.run { STOPPER.guard { (started << true) && resume.pop } && sleep } }
      started.pop
      [runner, resume]
    end

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end
  end
end
