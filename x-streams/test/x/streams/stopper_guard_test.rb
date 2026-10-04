# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # No stop is held back while a guarded block of a stream runs, and none is raised in a stream whose guarded block
  # runs: a stream stopped as its block runs is stopped once the block returns, and ends as the block does if it raises,
  # throws, or breaks
  class StopperGuardTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    STOPPER = Streams.const_get(:Stopper)

    def setup
      @stopper = STOPPER.new
    end

    def test_a_guarded_block_that_raises_once_stopped_raises_in_place_of_the_stop
      error = assert_raises(RuntimeError) { @stopper.run { STOPPER.guard { @stopper.stop || raise("boom") } } }

      assert_equal "boom", error.message
    end

    def test_a_guarded_block_that_breaks_once_stopped_returns_what_it_broke_with
      returned = @stopper.run do
        STOPPER.guard do
          @stopper.stop
          break :broken
        end
      end

      assert_equal :broken, returned
    end

    def test_a_guarded_block_that_throws_once_stopped_unwinds_to_the_catch
      thrown = catch(:out) do
        @stopper.run { STOPPER.guard { @stopper.stop || throw(:out, :thrown) } }
        :fell_through
      end

      assert_equal :thrown, thrown
      refute_predicate Thread.current, :pending_interrupt?
    end

    def test_a_guarded_block_of_a_stream_returns_what_its_block_returns
      assert_equal :value, @stopper.run { STOPPER.guard { :value } }
    end

    def test_a_guarded_block_of_a_stream_that_was_not_stopped_leaves_the_stream_running
      assert_equal :ran_on, @stopper.run { STOPPER.guard { sleep(0.01) } && sleep(0.01) && :ran_on }
    end

    def test_a_stream_begins_with_no_guarded_block_running
      assert_same false, STOPPER.const_get(:Stream).new.guarded
    end

    def test_a_guarded_block_that_breaks_with_no_stop_returns_what_it_broke_with
      assert_equal :broken, STOPPER.guard { break :broken }
    end

    def test_a_stop_in_a_guarded_block_raises_in_no_thread_and_stops_the_stream_once_the_block_returns
      pending = []
      returned = Thread.stub(:new, ->(*) { flunk "unexpected thread" }) do
        @stopper.run do
          STOPPER.guard { @stopper.stop || (pending << Thread.pending_interrupt?) }
          pending << :ran_on
          sleep
        end
      end

      assert_equal [nil, [false, :ran_on]], [returned, pending]
    end

    def test_a_stop_in_a_nested_guarded_block_is_held_back_only_once_the_outer_block_returns
      pending = []
      returned = @stopper.run do
        STOPPER.guard { STOPPER.guard { @stopper.stop } || (pending << Thread.pending_interrupt?) }
        sleep
      end

      assert_equal [nil, [false]], [returned, pending]
    end

    def test_a_stop_held_back_as_a_guarded_block_begins_is_discarded_until_the_block_returns
      pending = []
      returned = @stopper.run do
        @stopper.stop
        Thread.pass until Thread.pending_interrupt?
        STOPPER.guard { pending << Thread.pending_interrupt? }
        sleep
      end

      assert_equal [nil, [false]], [returned, pending]
    end
  end
end
