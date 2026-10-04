# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    # An exception raised in the caller as a worker is started stops the items not yet begun
    class ParallelStartTest < Minitest::Test
      cover Parallel

      # An exception raised in the caller, as an interrupt is
      class Interrupted < StandardError; end

      def test_an_exception_raised_in_the_caller_as_a_worker_is_started_stops_the_items_not_yet_begun
        began = Queue.new
        started = []
        assert_raises(Interrupted) do
          Thread.stub(:new, interrupting_at_the_second(started)) { Parallel.map(1..40, concurrency: 4) { |value| began << value.tap { sleep 0.01 } } }
        end
        started.each { |thread| thread.join(1) }

        assert_operator began.size, :<=, 2
      end

      private

      # Start threads as Thread.new does, raising an exception in the caller once the second is started
      def interrupting_at_the_second(started)
        start = Thread.method(:new)
        lambda do |*args, &block|
          start.call(*args, &block).tap { |thread| (started << thread).size.eql?(2) && Thread.current.raise(Interrupted) }
        end
      end
    end
  end
end
