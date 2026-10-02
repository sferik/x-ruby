# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stopper raises in the threads of the streams it runs, under a lock, so that it raises in no thread that is not
  # running one, and a stop is held back while a guarded block runs
  class StopperTest < Minitest::Test
    cover Streaming.const_get(:Stopper)

    STOPPER = Streaming.const_get(:Stopper)
    STOPPED = STOPPER.const_get(:Stopped)

    def setup
      @stopper = STOPPER.new
      @lock = @stopper.instance_variable_get(:@lock)
      @threads = []
    end

    def teardown
      @lock.unlock if @lock.owned?
      @threads.each(&:kill)
    end

    def test_a_run_returns_what_its_block_returns
      assert_equal :done, @stopper.run { :done }
      assert_equal 0, @stopper.stop
    end

    def test_a_stopped_run_returns_nil
      runner = start { @stopper.run { sleep } }
      wait_for(runner)

      assert_equal 1, @stopper.stop
      assert_nil runner.value
    end

    def test_stop_waits_for_the_lock
      runner = start { @stopper.run { sleep } }
      wait_for(runner)
      @lock.lock
      stopper = start { @stopper.stop }
      waiting = wait_for(stopper)
      @lock.unlock

      assert waiting
      assert_equal 1, stopper.value
    end

    def test_a_run_begins_under_the_lock
      began = Queue.new
      @lock.lock
      runner = start { @stopper.run { began << true } }
      wait_for(runner)

      assert_empty began
      @lock.unlock

      assert runner.value
    end

    def test_a_run_ends_under_the_lock
      runner = waiting_to_end
      ended = runner.join(0.1)
      @lock.unlock

      assert_nil ended
      assert_equal :done, runner.value
    end

    def test_a_stop_that_arrives_while_a_run_waits_to_end_is_held_until_it_has_ended
      runner = waiting_to_end
      runner.raise(STOPPED)
      @lock.unlock

      assert_nil runner.value
      assert_empty @stopper.instance_variable_get(:@streams)
    end

    def test_a_guarded_block_runs_to_its_end_before_the_stop
      started, resume, finished = Queue.new, Queue.new, []
      runner = start { @stopper.run { STOPPER.guard { (started << true) && resume.pop && (finished << true) } && sleep } }
      started.pop
      @stopper.stop
      resume << true

      assert_equal [nil, [true]], [runner.value, finished]
    end

    private

    # A thread whose run has ended, and waits for the lock, which this holds, to end it
    def waiting_to_end
      ran, resume = Queue.new, Queue.new
      runner = start { @stopper.run { (ran << true) && resume.pop } }
      ran.pop
      @lock.lock
      resume << :done
      wait_for(runner)
      runner
    end

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end

    # Wait until a thread waits, true once it does, or false if it ended
    def wait_for(thread)
      Thread.pass until thread.status.eql?("sleep") || !thread.alive?
      thread.alive?
    end
  end
end
