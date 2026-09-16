require_relative "../../test_helper"

module X
  class UserFindAllOrderTest < Minitest::Test
    cover User
    cover X::Objects::UserFinders

    def setup
      @client = FakeClient.new
    end

    def test_find_all_tells_an_identifier_from_a_username_of_the_same_digits
      @client.stub(:get, "users", {"data" => [{"id" => "1", "username" => "gem"}]})
      @client.stub(:get, "users/by", {"data" => [{"id" => "2", "username" => "1"}]})

      assert_equal [2, 1], User.find_all(["1", 1], client: @client).map(&:id)
    end

    def test_find_all_mixed_returns_users_in_the_order_asked_for
      @client.stub(:get, "users", {"data" => [{"id" => "1", "username" => "gem"}]})
      @client.stub(:get, "users/by", {"data" => [{"id" => "2", "username" => "Sferik"}]})

      assert_equal [2, 1], User.find_all(["@sferik", "nobody", User.from_id(1), 1, "SFERIK", 3], client: @client).map(&:id)
      assert_equal ["1,3", nil], @client.queries.map { |query| query["ids"] }
      assert_equal [nil, "sferik,nobody"], @client.queries.map { |query| query["usernames"] }
    end
  end
end
