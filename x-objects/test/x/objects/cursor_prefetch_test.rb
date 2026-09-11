require_relative "../../test_helper"

module X
  class CursorPrefetchTest < Minitest::Test
    cover Cursor

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}, {"id" => "2"}], "meta" => {"next_token" => "p2", "result_count" => 2}}
        when "p2" then {"data" => [{"id" => "3"}], "meta" => {"next_token" => "p3", "result_count" => 1}}
        when "p3" then {"data" => [{"id" => "4"}], "meta" => {"result_count" => 1}}
        end
      })
      @plain = Cursor.new(User, client: @client, path: "users/1/followers", params: {max_results: 1000})
      @cursor = @plain.prefetch
    end

    def test_prefetch_returns_new_cursor
      refute_same @plain, @cursor
      assert_predicate @cursor, :prefetch?
      refute_predicate @plain, :prefetch?
    end

    def test_prefetch_keeps_configuration
      assert_equal @plain.params, @cursor.params
      assert_equal "users/1/followers", @cursor.path
      assert_equal User, @cursor.klass
      assert_same @client, @cursor.client
    end

    def test_page_prefetches_the_next_page
      inline_threads { @cursor.page(0) }

      assert_equal [nil, "p2"], tokens
    end

    def test_page_prefetches_the_page_after_the_requested_one
      inline_threads { @cursor.page(1) }

      assert_equal [nil, "p2", "p3"], tokens
    end

    def test_last_page_prefetches_nothing
      inline_threads { @cursor.page(1) }
      Thread.stub(:new, ->(*) { flunk "unexpected thread" }) do
        @cursor.page(2)
        @cursor.page(3)
      end

      assert_equal 3, @client.requests.size
    end

    def test_without_prefetch_no_thread_is_started
      Thread.stub(:new, ->(*) { flunk "unexpected thread" }) { @plain.page(0) }

      assert_equal [nil], tokens
    end

    def test_prefetch_runs_in_a_background_thread
      @cursor.page(0)
      wait_for_requests(2)

      assert_equal %w[3], @cursor.page(1).map(&:id)
    end

    def test_prefetch_error_resurfaces_when_page_is_requested
      stub_failing_second_page
      inline_threads { @cursor.page(0) }

      assert_raises(RuntimeError) { @cursor.page(1) }
      assert_equal 3, @client.requests.size
    end

    def test_prefetch_errors_do_not_escape_the_thread
      stub_failing_second_page
      thread = nil
      Thread.stub(:new, ->(&block) { thread = Thread.start(&block) }) { @cursor.page(0) }

      assert_nil thread.value
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

    def tokens
      @client.queries.map { |query| query["pagination_token"] }
    end

    def wait_for_requests(count)
      deadline = Time.now + 1
      sleep 0.01 until @client.requests.size >= count || Time.now > deadline
    end
  end
end
