# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream a Fiber scheduler runs waits on the API in the scheduler, so stop raises in no thread for it, which would
  # end the scheduler, and stops it instead as its block returns, or at the next keep-alive
  class StopperSchedulerTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    STOPPER = Streams.const_get(:Stopper)

    def setup
      @stopper = STOPPER.new
    end

    def test_a_stream_a_fiber_scheduler_runs_is_stopped_as_its_block_returns_and_raised_in_by_no_stop
      scheduled do
        fiber = Fiber.new(blocking: false) { @stopper.run { Fiber.yield || STOPPER.guard { nil } || :ran_on } }
        fiber.resume
        Thread.stub(:new, ->(*) { flunk "unexpected thread" }) { @stopper.stop }

        refute_predicate Thread.current, :pending_interrupt?
        assert_nil fiber.resume
      end
    end

    def test_a_stream_a_fiber_scheduler_runs_is_stopped_at_a_keep_alive
      called = []
      scheduled do
        fiber = Fiber.new(blocking: false) { @stopper.run { @stopper.stop || STOPPER.checking(-> { called << 1 }).call || :ran_on } }

        assert_equal [nil, [1]], [fiber.resume, called]
      end
    end

    def test_a_keep_alive_of_a_stream_that_was_not_stopped_leaves_it_running
      called = []

      assert_equal :ran_on, @stopper.run { STOPPER.checking(-> { called << 1 }).call || :ran_on }
      assert_nil STOPPER.checking(-> { called << 2 }).call
      assert_equal [1, 2], called
    end

    def test_a_stream_a_fiber_scheduler_runs_waits_to_reconnect_a_second_at_a_time
      slept = []
      scheduled { Fiber.new(blocking: false) { @stopper.run { STOPPER.pausing(2.5) { |seconds| slept << seconds } } }.resume }

      assert_equal [1, 1, 0.5], slept
    end

    def test_a_stream_a_fiber_scheduler_runs_that_is_stopped_as_it_waits_to_reconnect_is_stopped_within_a_second
      slept = []
      returned = scheduled do
        Fiber.new(blocking: false) { @stopper.run { STOPPER.pausing(5) { |seconds| (slept << seconds) && @stopper.stop } || :ran_on } }.resume
      end

      assert_equal [nil, [1]], [returned, slept]
    end

    def test_a_stream_a_fiber_scheduler_runs_that_was_stopped_is_stopped_before_it_reconnects
      returned = scheduled { Fiber.new(blocking: false) { @stopper.run { @stopper.stop || STOPPER.pausing(0) { flunk } || :ran_on } }.resume }

      assert_nil returned
    end

    def test_any_other_stream_waits_to_reconnect_at_once
      slept = []

      assert_equal :ran_on, @stopper.run { STOPPER.pausing(2.5) { |seconds| slept << seconds } && :ran_on }
      STOPPER.pausing(1.5) { |seconds| slept << seconds }

      assert_equal [2.5, 1.5], slept
    end

    def test_a_stream_runs_in_no_fiber_scheduler_unless_one_runs_its_non_blocking_fiber
      stream = STOPPER.const_get(:Stream)
      blocking = scheduled { stream.new.scheduled }
      unscheduled = Fiber.new(blocking: false) { stream.new.scheduled }.resume

      assert_equal [false, false, true], [blocking, unscheduled, scheduled { Fiber.new(blocking: false) { stream.new.scheduled }.resume }]
    end

    private

    # Run a block as though a Fiber scheduler were set for the thread
    def scheduled(&) = Fiber.stub(:scheduler, Object.new, &)
  end
end
