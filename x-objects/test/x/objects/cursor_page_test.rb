# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CursorPageTest < Minitest::Test
    cover Cursor
    cover Objects::Pages

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}, {"id" => "2"}], "meta" => {"next_token" => "p2", "result_count" => 2}}
        when "p2" then {"data" => [{"id" => "3"}], "meta" => {"next_token" => "p3", "result_count" => 1}}
        when "p3" then {"data" => [{"id" => "4"}], "meta" => {"result_count" => 1}}
        end
      })
      @cursor = Cursor.new(User, "users/1/followers", client: @client, params: {max_results: 1000})
    end

    def test_page_by_index
      assert_equal [3], @cursor.page(1).map(&:id)
      assert_equal 2, @client.requests.size
      assert_equal ["p2"], @client.queries.last.values_at("pagination_token")
    end

    def test_page_past_last
      assert_nil @cursor.page(3)
      assert_equal 3, @client.requests.size
      assert_nil @cursor.page(4)
      assert_equal 3, @client.requests.size
    end

    def test_a_negative_page_index_is_refused
      assert_equal "-1 is not a page index: pages are numbered from zero", assert_raises(ArgumentError) { @cursor.page(-1) }.message
      assert_empty @client.requests
      @cursor.to_a

      assert_raises(ArgumentError) { @cursor.page(-1) }
      assert_raises(ArgumentError) { @cursor.page(-2) }
    end

    def test_a_far_page_reads_the_pages_before_it_in_order
      assert_nil @cursor.page(1_000)
      assert_equal %w[p2 p3], @client.queries.drop(1).map { |query| query["pagination_token"] }
      assert_equal 3, @client.requests.size
    end

    def test_page_items_hold_client
      assert_same @client, @cursor.page(0).items.first.client
    end

    def test_page_without_data
      @client.stub(:get, "users/1/followers", {"meta" => {"result_count" => 0}})
      page = @cursor.page(0)

      assert_empty page.items
      assert_equal 0, page.result_count
      assert_nil @cursor.page(1)
    end

    def test_page_meta
      assert_equal({"next_token" => "p2", "result_count" => 2}, @cursor.page(0).meta)
    end

    def test_page_with_nil_body
      @client.stub(:get, "users/1/followers", nil)
      page = @cursor.page(0)

      assert_empty page.items
      assert_empty page.meta
    end

    def test_failed_page_is_not_cached
      @client.stub(:get, "users/1/followers", ->(_, _) { raise "boom" })
      assert_raises(RuntimeError) { @cursor.page(0) }
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "1"}]})

      assert_equal [1], @cursor.page(0).map(&:id)
    end

    def test_refresh_returns_new_cursor_without_cache
      @cursor.to_a
      refreshed = @cursor.refresh
      refreshed.to_a

      refute_same @cursor, refreshed
      assert_equal 6, @client.requests.size
    end

    def test_refresh_keeps_configuration
      refreshed = @cursor.refresh

      assert_equal @cursor.params, refreshed.params
      assert_equal "users/1/followers", refreshed.path
      assert_equal User, refreshed.resource_class
      assert_same @client, refreshed.client
    end

    def test_refresh_keeps_prefetch
      assert_predicate @cursor.prefetch.refresh, :prefetch?
      refute_predicate @cursor.refresh, :prefetch?
    end
  end
end
