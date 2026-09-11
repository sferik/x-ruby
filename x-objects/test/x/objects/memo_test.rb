require_relative "../../test_helper"

module X
  module Objects
    class MemoTest < Minitest::Test
      cover Memo

      def setup
        @memo = Memo.new
      end

      def test_fetch_computes_once
        calls = 0
        2.times { @memo.fetch { calls += 1 } }

        assert_equal 1, calls
      end

      def test_fetch_returns_memoized_value
        @memo.fetch { "value" }

        assert_equal "value", @memo.fetch { "other" }
      end

      def test_fetch_memoizes_nil
        calls = 0
        2.times do
          @memo.fetch do
            calls += 1
            nil
          end
        end

        assert_equal 1, calls
      end

      def test_fetch_memoizes_false
        refute @memo.fetch { false }
        refute @memo.fetch { true }
      end

      def test_fetch_is_reentrant
        other = Memo.new

        assert_equal "inner", @memo.fetch { other.fetch { "inner" } }
      end

      def test_fetch_serializes_computation_across_threads
        calls = Queue.new
        threads = Array.new(4) { Thread.new { @memo.fetch { slow_value(calls) } } }

        assert_equal %w[value value value value], threads.map(&:value)
        assert_equal 1, calls.size
      end

      def test_store_replaces_value
        @memo.fetch { "old" }

        assert_equal "new", @memo.store("new")
        assert_equal "new", @memo.fetch { "other" }
      end

      def test_store_waits_for_a_fetch_in_progress
        started = Queue.new
        fetching = Thread.new { @memo.fetch { slow_value(started) } }
        started.pop
        @memo.store("stored")
        fetching.join

        assert_equal "stored", @memo.fetch { "other" }
        assert_equal "value", fetching.value
      end

      def test_store_before_fetch
        @memo.store(nil)

        assert_nil @memo.fetch { "other" }
      end

      def test_unset_is_frozen
        assert_predicate Memo::UNSET, :frozen?
      end

      private

      def slow_value(calls)
        calls << true
        sleep 0.05
        "value"
      end
    end
  end
end
