require_relative "../../test_helper"

module X
  class CursorEmptyPageTest < Minitest::Test
    cover Cursor
    cover Objects::Pages

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}], "meta" => {"next_token" => "p2"}})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def stub_filtered_first_page
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        query["pagination_token"] ? {"data" => [{"id" => "7"}]} : {"meta" => {"result_count" => 0, "next_token" => "p2"}}
      })
    end

    def test_first_reads_past_an_empty_page_that_names_a_next_page
      stub_filtered_first_page

      assert_equal 7, @user.followers.first.id
      assert_equal [{"max_results" => "1"}, {"max_results" => "1", "pagination_token" => "p2"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_the_predicates_read_past_an_empty_page_that_names_a_next_page
      stub_filtered_first_page

      assert_predicate @user.followers, :any?
      refute_predicate @user.followers, :none?
      refute_predicate @user.followers, :empty?
      assert_predicate @user.followers, :one?
    end

    def test_empty_requests_one_resource
      refute_predicate @user.followers, :empty?
      assert_equal [{"max_results" => "1"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_a_collection_without_a_resource_is_empty
      @client.stub(:get, "users/1/followers", {"meta" => {"result_count" => 0}})

      assert_predicate @user.followers, :empty?
      assert_predicate @user.followers, :none?
      refute_predicate @user.followers, :any?
    end
  end
end
