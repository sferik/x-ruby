require_relative "../../test_helper"

module X
  class CursorPagingTest < Minitest::Test
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

    def test_first_beyond_the_page_size_asks_the_next_page_for_what_is_left
      assert_equal [1, 2, 3, 1], @user.followers(max_results: 3).first(4).map(&:id)
      assert_equal %w[3 1], @client.queries.map { |query| query["max_results"] }
    end

    def test_a_page_after_the_first_asks_for_no_more_than_the_page_size
      stub_paging_followers
      cursor = Cursor.new(User, "users/2/followers", client: @client, params: {max_results: 3})

      assert_equal 7, cursor.first(7).size
      assert_equal %w[3 3 1], @client.queries.map { |query| query["max_results"] }
    end

    def test_a_cursor_with_a_limit_ends_once_it_has_what_it_asked_for
      stub_paging_followers
      cursor = Cursor.new(User, "users/2/followers", client: @client, params: {max_results: "3"}, limit: 7)

      assert_equal 7, cursor.to_a.size
      assert_equal %w[3 3 1], @client.queries.map { |query| query["max_results"] }
    end

    def test_a_page_after_the_first_rises_to_the_minimum_of_the_endpoint
      cursor = Cursor.new(User, "users/1/followers", client: @client, params: {max_results: 10}, min_results: 5)

      assert_equal 12, cursor.first(12).size
      assert_equal %w[10 5], @client.queries.map { |query| query["max_results"] }
    end

    def test_the_pages_of_a_cursor_are_frozen
      assert_predicate Objects::Pages.new(@user.followers, nil), :frozen?
    end

    private

    def stub_paging_followers
      tokens = {nil => "p1", "p1" => "p2", "p2" => "p3"}
      @client.stub(:get, "users/2/followers", lambda { |query, _|
        size = query.fetch("max_results").to_i
        {"data" => (1..size).map { |id| {"id" => id.to_s} }, "meta" => {"next_token" => tokens[query["pagination_token"]]}.compact}
      })
    end
  end
end
