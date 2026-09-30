# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class APITimelinesTest < Minitest::Test
      cover Objects.const_get(:Lookups)
      cover Post
      cover Objects.const_get(:PostSearch)

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9", "username" => "sferik"}})
      end

      def test_current_user
        assert_equal "sferik", @client.current_user!.username
        assert_equal ["users/me"], @client.paths
      end

      def test_the_identifier_of_the_current_user_is_kept_while_the_authenticator_is
        client = client_with_authenticator
        client.current_user!
        client.stub(:get, "users/me", {"data" => {"id" => "12", "username" => "jack"}})

        assert_equal 9, client.current_user_id
        assert_equal ["users/me"], client.paths
      end

      def test_current_user_missing
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(MissingResource) { @client.current_user! }

        assert_equal "users/me returned no user", error.message
      end

      def test_search_users
        cursor = @client.search_users("ruby", max_results: 10)

        assert_equal "users/search", cursor.__send__(:path)
        assert_equal ["ruby", 10, "next_token"], [cursor.__send__(:params)["query"], cursor.__send__(:params)["max_results"], cursor.__send__(:token_param)]
        assert_equal User, cursor.resource_class
        assert_same @client, cursor.client
      end

      def test_reposts_of_me
        cursor = @client.reposts_of_me(max_results: 10)

        assert_equal ["users/reposts_of_me", 10, Post], [cursor.__send__(:path), cursor.__send__(:params)["max_results"], cursor.resource_class]
        assert_same @client, cursor.client
        assert_equal "users/reposts_of_me", @client.retweets_of_me.__send__(:path)
        assert_equal "users/reposts_of_me", Post.retweets_of_me(client: @client).__send__(:path)
      end

      def test_reposts_of_me_requests_the_largest_page
        assert_equal 100, @client.reposts_of_me.__send__(:params)["max_results"]
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
