# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream stopped as it reads keep-alives, or stopped more than once, discards every stop it holds back as it ends,
  # however many it holds, so none is left for the caller once the stream returns, nor cuts a guarded block short
  class StopperKeepAliveTest < Minitest::Test
    cover Streams.const_get(:Stopper)

    STOPPER = Streams.const_get(:Stopper)

    def test_keep_alives_read_once_stopped_leave_no_stop_for_the_caller
      stopper = STOPPER.new
      returned = stopper.run do
        STOPPER.guard { stopper.stop }
        3.times { STOPPER.checking(-> {}).call }
        sleep
      end

      assert_nil returned
      refute_predicate Thread.current, :pending_interrupt?
    end

    def test_an_exception_of_another_kind_held_back_leaves_the_stream_to_be_stopped
      held_back, returned = Class.new(StandardError), :unset
      assert_raises(held_back) { Thread.handle_interrupt(held_back => :never) { returned = stopped_holding_back(held_back) } }

      assert_nil returned
    end

    def test_every_stop_held_back_as_a_stream_ends_is_discarded
      stopper = STOPPER.new
      stop = stopper.instance_variable_get(:@stop)

      assert_equal :done, stopper.run { 3.times { Thread.current.raise(stop) } && :done }
      refute_predicate Thread.current, :pending_interrupt?
    end

    def test_every_stop_held_back_as_a_guarded_block_begins_is_discarded
      stopper = STOPPER.new
      stop = stopper.instance_variable_get(:@stop)

      assert_equal :slept, stopper.run { 2.times { Thread.current.raise(stop) } && STOPPER.guard { sleep(0.01) && :slept } }
    end

    private

    # Run a stream that holds back an exception of a class, is stopped as its block runs, and then waits a second
    def stopped_holding_back(held_back)
      stopper = STOPPER.new
      stopper.run do
        Thread.current.raise(held_back)
        STOPPER.guard { stopper.stop }
        sleep(1) && :ran_on
      end
    end
  end
end
