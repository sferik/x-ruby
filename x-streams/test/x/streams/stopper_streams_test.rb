# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stop of one stream never ends another of the same thread, whether one is held in its guarded block by a Fiber,
  # or runs in the other
  class StopperStreamsTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    STOPPER = Streams.const_get(:Stopper)

    def setup
      @stopper = STOPPER.new
      @threads = []
    end

    def teardown
      @threads.each(&:kill)
    end

    def test_a_stop_of_a_stream_held_in_its_guarded_block_by_a_fiber_does_not_stop_another_stream
      fiber = Fiber.new { @stopper.run { STOPPER.guard { Fiber.yield(:held) } && sleep } }
      fiber.resume
      @stopper.stop

      assert_equal :other, STOPPER.new.run { sleep(0.01) && :other }
      assert_nil fiber.resume
    end

    def test_a_stop_of_a_stream_ends_a_stream_of_another_stopper_that_runs_in_it_and_not_its_stopper
      inner = STOPPER.new
      runner = start { @stopper.run { [inner.run { sleep }, :ran_on] } }
      Thread.pass until runner.status.eql?("sleep")
      @stopper.stop

      assert_nil runner.value
      refute_predicate inner, :stopped?
    end

    def test_a_stream_is_the_stream_of_its_fiber_again_once_a_stream_run_in_it_ends
      inner = STOPPER.new
      returned = Thread.stub(:new, ->(*) { flunk "unexpected thread" }) do
        @stopper.run do
          inner.run { :inner }
          STOPPER.guard { @stopper.stop }
          sleep
        end
      end

      assert_nil returned
    end

    private

    # Start a thread, which teardown kills if it is still running
    def start(&)
      Thread.new(&).tap { |thread| (@threads << thread) && thread.report_on_exception = false }
    end
  end
end
