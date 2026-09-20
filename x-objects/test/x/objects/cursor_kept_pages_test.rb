require_relative "../../test_helper"

module X
  class CursorKeptPagesTest < Minitest::Test
    cover Cursor
    cover Objects::Pages

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        size = query.fetch("max_results", "3").to_i
        {"data" => (1..size).map { |id| {"id" => id.to_s} }, "meta" => {"next_token" => "p2"}.reject { query["pagination_token"] }}
      })
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_first_keeps_the_page_it_read_for_the_calls_after_it
      followers = @user.followers
      followers.first
      followers.first
      followers.empty?
      followers.any?

      assert_equal [{"max_results" => "1"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_an_iteration_after_first_requests_only_what_first_left
      followers = @user.followers
      followers.first
      followers.each { |_follower| }

      assert_equal [{"max_results" => "1"}, {"max_results" => "1000", "pagination_token" => "p2"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_a_larger_first_after_a_smaller_one_requests_only_the_difference
      followers = @user.followers

      assert_equal [1], followers.first(1).map(&:id)
      assert_equal [1, 1, 2], followers.first(3).map(&:id)
      assert_equal [{"max_results" => "1"}, {"max_results" => "2", "pagination_token" => "p2"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_first_after_an_iteration_reads_the_pages_it_holds
      followers = @user.followers
      followers.each { |_follower| }
      followers.first(2)

      assert_equal %w[1000 1000], @client.queries.map { |query| query["max_results"] }
    end
  end
end
