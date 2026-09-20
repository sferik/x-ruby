# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CursorCacheTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover User

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        size = query.fetch("max_results", "3").to_i
        {"data" => (1..size).map { |id| {"id" => id.to_s} }, "meta" => {"next_token" => "p2"}.reject { query["pagination_token"] }}
      })
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_first_answers_from_the_pages_the_cursor_already_holds
      followers = @user.followers(max_results: 3)
      followers.to_a

      assert_equal [1, 2, 3], followers.first(3).map(&:id)
      assert_equal 1, followers.first.id
      assert_equal [1, 2], followers.take(2).map(&:id)
      assert_equal 2, @client.requests.size
    end

    def test_first_of_more_than_a_read_collection_holds_answers_from_it
      followers = @user.followers(max_results: 3)
      followers.to_a

      assert_equal [1, 2, 3, 1, 2, 3], followers.first(10).map(&:id)
      assert_equal 2, @client.requests.size
    end

    def test_a_cursor_read_to_its_end_answers_the_predicates_without_a_request
      followers = @user.followers(max_results: 3)
      followers.to_a
      requests = @client.requests.size

      refute_predicate followers, :empty?
      assert_predicate followers, :any?
      refute_predicate followers, :none?
      refute_predicate followers, :one?
      assert_equal requests, @client.requests.size
    end

    def test_first_waits_for_a_page_another_thread_is_fetching_rather_than_ask_again
      @client.stub(:get, "users/1/followers", lambda { |_, _|
        sleep 0.05
        {"data" => [{"id" => "1"}, {"id" => "2"}, {"id" => "3"}]}
      })
      followers = @user.followers(max_results: 3)
      thread = Thread.new { followers.page(0) }
      sleep 0.001 until @client.requests.size.positive?
      first = followers.first
      thread.join

      assert_equal [1, 1], [first.id, @client.requests.size]
    end

    def test_first_answers_from_a_cached_page_that_is_not_the_last_of_the_collection
      followers = @user.followers(max_results: 3)
      followers.page(0)

      assert_equal [1, 2, 3], followers.first(3).map(&:id)
      assert_equal [1, 2], followers.take(2).map(&:id)
      assert_equal 1, @client.requests.size
    end

    def test_a_cursor_whose_pages_fall_short_asks_for_the_rest_in_the_pages_after_them
      followers = @user.followers(max_results: 3)
      followers.page(0)

      assert_equal [1, 2, 3, 1, 2, 3], followers.first(6).map(&:id)
      assert_equal [{"max_results" => "3"}, {"max_results" => "3", "pagination_token" => "p2"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_stubs_keeps_prefetching
      cursor = @user.followers

      assert_predicate cursor.prefetch.stubs, :prefetch?
      refute_predicate cursor.stubs, :prefetch?
      assert_predicate cursor.stubs.prefetch, :prefetch?
    end

    def test_the_identifiers_of_a_prefetching_cursor_prefetch
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        {"data" => [{"id" => query["pagination_token"] ? "2" : "1"}], "meta" => {"next_token" => "p2"}.reject { query["pagination_token"] }}
      })
      threads = 0
      ids = Thread.stub(:new, ->(&block) { threads += 1 and block.call }) { @user.followers.prefetch.ids }

      assert_equal [[1, 2], 1], [ids, threads]
    end

    def test_prefetching_stops_once_the_count_is_read
      Thread.stub(:new, ->(&block) { block.call }) do
        assert_equal [1, 2, 3], @user.followers(max_results: 100).prefetch.first(3).map(&:id)
      end

      assert_equal [{"max_results" => "3"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_a_cursor_answers_no_size
      refute_respond_to @user.followers, :size
      assert_empty @client.requests
    end

    def test_a_sized_enumerator_does_not_page_the_collection
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})

      assert_nil @user.followers.each_slice(2).size
      assert_nil @user.followers.lazy.size
      assert_empty @client.requests
    end
  end
end
