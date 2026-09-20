require_relative "../../test_helper"

module X
  module Objects
    class APIUsernameLookupsTest < Minitest::Test
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_find_users_by_username
        @client.stub(:get, "users/by", {"data" => [{"id" => "1", "username" => "sferik"}, {"id" => "2", "username" => "1234"}],
                                        "errors" => [{"title" => "Not Found Error", "detail" => "Could not find user with usernames: [nobody]."}]})
        problems = []
        users = @client.find_users_by_username(["@sferik", "1234", "nobody"], "user.fields": "id") { |problem| problems << problem }

        assert_equal %w[sferik 1234], users.map(&:username)
        assert_equal "sferik,1234,nobody", @client.queries.first["usernames"]
        assert_equal "id", @client.queries.first["user.fields"]
        assert_equal ["Not Found Error"], problems.map(&:title)
      end
    end
  end
end
