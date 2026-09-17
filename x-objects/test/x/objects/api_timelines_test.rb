require_relative "../../test_helper"

module X
  module Objects
    class APITimelinesTest < Minitest::Test
      cover API::Lookups
      cover Post

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9", "username" => "sferik"}})
      end

      def test_current_user
        assert_equal "sferik", @client.current_user.username
        assert_same @client.current_user, @client.current_user
        assert_equal ["users/me"], @client.paths
      end

      def test_current_user_is_kept_while_the_authenticator_is
        client = client_with_authenticator
        first = client.current_user
        client.stub(:get, "users/me", {"data" => {"id" => "12", "username" => "jack"}})

        assert_same first, client.current_user
        assert_equal ["users/me"], client.paths
      end

      def test_current_user_is_fetched_again_for_a_new_authenticator
        client = client_with_authenticator
        client.current_user
        client.stub(:get, "users/me", {"data" => {"id" => "12", "username" => "jack"}})
        client.authenticator = Object.new

        assert_equal %w[jack jack], [client.current_user.username, client.current_user.username]
        assert_equal ["users/me"] * 2, client.paths
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

      def test_reposts_of_me
        cursor = @client.reposts_of_me(max_results: 10)

        assert_equal ["users/reposts_of_me", 10, Post], [cursor.path, cursor.params["max_results"], cursor.klass]
        assert_same @client, cursor.client
        assert_equal "users/reposts_of_me", @client.retweets_of_me.path
      end

      def test_reposts_of_me_requests_the_largest_page
        assert_equal 100, @client.reposts_of_me.params["max_results"]
      end

      private

      def client_with_authenticator
        client = Class.new(FakeClient) { attr_accessor :authenticator }.new
        client.stub(:get, "users/me", {"data" => {"id" => "9", "username" => "sferik"}})
        client.authenticator = Object.new
        client
      end
    end
  end
end
