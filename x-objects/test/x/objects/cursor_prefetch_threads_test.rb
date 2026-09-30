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

    def test_a_prefetch_that_failed_is_started_again
      stub_failing_second_page
      inline_threads { 2.times { @cursor.page(0) } }

      assert_equal [nil, "p2", "p2"], tokens
    end

    def test_a_page_is_claimed_once_until_it_is_let_go
      pages = Objects.const_get(:Pages).new(@cursor)
      claims = Array.new(2) { pages.__send__(:claim, 1) }
      pages.at(0)

      assert_equal [true, false, false], claims + [pages.__send__(:claim, 0)]
    end

    def test_a_page_is_claimed_and_let_go_holding_the_lock_of_the_pages
      pages = Objects.const_get(:Pages).new(@cursor)
      [-> { pages.__send__(:claim, 1) }, -> { pages.__send__(:let_go, 1) }].each do |step|
        running = nil
        pages.instance_variable_get(:@monitor).synchronize do
          running = Thread.start(&step)

          assert_nil running.join(0.05)
        end
        running.join
      end

      assert pages.__send__(:claim, 1)
    end

    private

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
