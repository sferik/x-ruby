# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stopper raises in the threads of the streams it runs, under a lock, so that it raises in no thread that is not
  # running one, and a stop is held back while a guarded block runs, and a stopper that was stopped runs no stream again
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
      assert_nil @stopper.stop
    end

    def test_a_stopper_is_stopped_once_stop_is_called
      assert_same false, @stopper.stopped?
      @stopper.stop

      assert_predicate @stopper, :stopped?
    end

    def test_a_run_after_a_stop_returns_nil_without_running_its_block
      @stopper.stop
      ran = false

      assert_nil @stopper.run { ran = true }
      refute ran
      assert_empty @stopper.instance_variable_get(:@streams)
    end

    def test_a_stopped_run_returns_nil
      runner = start { @stopper.run { sleep } }
      wait_for(runner)

      assert_nil @stopper.stop
      assert_nil runner.value
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

    def test_a_guarding_callable_runs_its_callable_to_its_end_before_the_stop
      started, resume, finished = Queue.new, Queue.new, []
      guarding = STOPPER.guarding(->(object) { (started << true) && resume.pop && (finished << object) })
      runner = start { @stopper.run { guarding.call(:object) && sleep } }

      assert_equal [nil, [:object]], [stop_once(started, resume, runner), finished]
    end

    def test_a_guarding_callable_passes_its_callable_what_it_is_passed_and_returns_what_it_returns
      assert_equal [1, 2], STOPPER.guarding(->(*arguments) { arguments }).call(1, 2)
    end

    def test_no_callable_is_guarded_by_none
      assert_nil STOPPER.guarding(nil)
    end

    private

    # Stop the stopper once a run has started, resume the run, and return what it returned
    def stop_once(started, resume, runner)
      started.pop
      @stopper.stop
      resume << true
      runner.value
    end

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
