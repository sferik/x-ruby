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
