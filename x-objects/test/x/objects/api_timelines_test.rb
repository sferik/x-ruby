require_relative "../../test_helper"

module X
  module Objects
    class APITimelinesTest < Minitest::Test
      cover API::Lookups

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9", "username" => "sferik"}})
      end

      def test_current_user
        assert_equal "sferik", @client.current_user.username
        assert_same @client.current_user, @client.current_user
        assert_equal ["users/me"], @client.paths
      end

      def test_current_user_missing
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(ResourceNotFound) { @client.current_user }

        assert_equal "users/me returned no user", error.message
      end

      def test_search_users
        cursor = @client.search_users("ruby", max_results: 10)

        assert_equal "users/search", cursor.path
        assert_equal ["ruby", 10, "next_token"], [cursor.params["query"], cursor.params["max_results"], cursor.token_param]
        assert_equal User, cursor.klass
        assert_same @client, cursor.client
      end
    end
  end
end
