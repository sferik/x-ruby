# frozen_string_literal: true

require "timeout"
require_relative "../../test_helper"

module X
  module Objects
    class ParallelTest < Minitest::Test
      cover Parallel

      def test_map_preserves_order
        results = Parallel.map([3, 1, 2]) do |value|
          sleep(value / 100.0)
          value * 2
        end

        assert_equal [6, 2, 4], results
      end

      def test_map_with_empty_items
        assert_empty Parallel.map([]) { |value| value }
      end

      def test_map_accepts_enumerables
        assert_equal [2, 4], Parallel.map(1..2) { |value| value * 2 }
      end

      def test_map_runs_in_other_threads
        threads = Parallel.map([1, 2]) { Thread.current }

        refute_includes threads, Thread.current
      end

      def test_map_starts_at_most_concurrency_threads
        assert_equal 2, count_threads { Parallel.map(1..5, concurrency: 2) { |value| value } }
      end

      def test_map_starts_at_most_one_thread_per_item
        assert_equal 3, count_threads { Parallel.map(1..3, concurrency: 8) { |value| value } }
      end

      def test_map_default_concurrency
        assert_equal Parallel::DEFAULT_CONCURRENCY, count_threads { Parallel.map(1..20) { |value| value } }
      end

      def test_map_raises_block_errors
        error = assert_raises(RuntimeError) do
          Parallel.map([1, 2]) { |value| raise "boom #{value}" if value.eql?(2) }
        end

        assert_equal "boom 2", error.message
      end

      def test_map_stops_the_items_not_yet_begun_after_an_error
        calls = Queue.new
        assert_raises(RuntimeError) { Parallel.map(1..6, concurrency: 2) { |value| failing_after_others(value, calls) } }

        assert_equal 2, calls.size
      end

      def test_map_waits_for_the_items_already_begun
        finished = Queue.new
        assert_raises(RuntimeError) do
          Parallel.map(1..2, concurrency: 2) { |value| failing_after_others(value, Queue.new).tap { finished << value } }
        end

        assert_equal [2], Array.new(finished.size) { finished.pop }
      end

      def test_map_raises_the_error_raised_first
        error = assert_raises(RuntimeError) do
          Parallel.map(1..2, concurrency: 2) { |value| failing_after_others(value, Queue.new) && raise("boom #{value}") }
        end

        assert_equal "boom 1", error.message
      end

      def test_map_stops_the_items_not_yet_begun_when_the_wait_is_interrupted
        began = Queue.new
        gate = Queue.new
        assert_raises(Timeout::Error) do
          Timeout.timeout(0.1) { Parallel.map(1..40, concurrency: 2) { |value| began << value.tap { gate.pop } } }
        end
        40.times { gate << true }
        sleep 0.05

        assert_equal 2, began.size
      end

      def test_map_gives_every_item_a_place_in_the_results_before_a_thread_starts
        assert_equal [nil, nil, nil], Parallel.map(1..3, concurrency: 0) { |value| value }
      end

      def test_map_does_not_report_exceptions_on_stderr
        _, err = capture_subprocess_io do
          Parallel.map([1]) { raise "boom" }
        rescue RuntimeError
          nil
        end

        assert_empty err
      end

      def test_map_leaves_global_exception_reporting_alone
        previous = Thread.report_on_exception
        Thread.report_on_exception = true
        Parallel.map([1]) { |value| value }

        assert Thread.report_on_exception
      ensure
        Thread.report_on_exception = previous
      end

      private

      # Raise for the first item after a short wait, and return any other after a longer one
      def failing_after_others(value, calls)
        calls << value
        sleep(value.eql?(1) ? 0.01 : 0.05)
        raise "boom #{value}" if value.eql?(1)

        value
      end

      def count_threads(&)
        count = 0
        original = Thread.method(:new)
        Thread.stub(:new, lambda { |&block|
          count += 1
          original.call(&block)
        }, &)
        count
      end
    end
  end
end
