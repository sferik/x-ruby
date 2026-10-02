# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A cursor that prefetches starts a thread for a page only when no page is fetched there, and no thread is fetching it
  class CursorPrefetchThreadsTest < Minitest::Test
    cover Objects.const_get(:Pages)

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "2"}], "meta" => {"next_token" => "p3"}}
        when "p3" then {"data" => [{"id" => "3"}], "meta" => {}}
        end
      })
      @cursor = Cursor.__send__(:build, User, "users/1/followers", client: @client, prefetch: true)
    end

    def test_a_page_already_fetched_starts_no_thread
      inline_threads { @cursor.page(1) }
      Thread.stub(:new, ->(*) { flunk "unexpected thread" }) do
        @cursor.page(0)
        @cursor.page(0)
      end

      assert_equal [nil, "p2", "p3"], tokens
    end

    def test_a_page_another_thread_is_fetching_starts_no_thread
      started = []
      Thread.stub(:new, ->(&block) { started << block }) do
        @cursor.page(0)
        @cursor.page(0)
      end
      started.each(&:call)

      assert_equal [1, [nil, "p2"]], [started.size, tokens]
    end

    def test_a_page_a_prefetch_failed_to_fetch_is_requested_again_once_its_error_is_raised
      stub_failing_second_page
      inline_threads do
        2.times { @cursor.page(0) }

        assert_equal [nil, "p2"], tokens
        assert_raises(RuntimeError) { @cursor.page(1) }
        @cursor.page(0)
      end

      assert_equal [nil, "p2", "p2"], tokens
    end

    def test_a_page_is_claimed_once_until_it_is_let_go
      pages = Objects.const_get(:Pages).new(@cursor)
      claims = Array.new(2) { pages.__send__(:claim, 1) }
      pages.at(0)

      assert_equal [true, false, false], claims + [pages.__send__(:claim, 0)]
    end

    def test_a_page_is_claimed_holding_the_lock_of_the_pages
      pages = Objects.const_get(:Pages).new(@cursor)
      running = nil
      pages.instance_variable_get(:@monitor).synchronize do
        running = Thread.start { pages.__send__(:claim, 1) }

        assert_nil running.join(0.05)
      end

      assert running.value
    end

    def test_a_page_is_let_go_once_its_thread_is_done
      pages = Objects.const_get(:Pages).new(@cursor)
      started = []
      Thread.stub(:new, ->(&block) { started << block }) { pages.at(0) }

      refute pages.__send__(:claim, 1)
      started.each(&:call)

      assert_empty pages.instance_variable_get(:@prefetching)
    end

    def test_a_failure_is_kept_and_its_page_let_go_holding_the_lock_of_the_pages
      stub_failing_second_page
      pages = Objects.const_get(:Pages).new(@cursor)
      owned = []
      watch(pages, owned, :@failures, :[]=)
      watch(pages, owned, :@prefetching, :delete)
      inline_threads { pages.at(0) }

      assert_equal [true, true], owned
    end

    private

    # Record whether the lock of the pages is held each time a method of one of their instance variables is called
    def watch(pages, owned, variable, method)
      monitor = pages.instance_variable_get(:@monitor)
      pages.instance_variable_get(variable).define_singleton_method(method) do |*args|
        owned << monitor.mon_owned?
        super(*args)
      end
    end

    def inline_threads(&)
      Thread.stub(:new, ->(&block) { block.call }, &)
    end

    def stub_failing_second_page
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        raise "boom" if query["pagination_token"]

        {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
      })
    end

    def tokens = @client.queries.map { |query| query["pagination_token"] }
  end
end
