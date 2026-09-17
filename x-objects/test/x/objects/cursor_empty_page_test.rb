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
