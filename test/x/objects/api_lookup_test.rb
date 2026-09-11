require_relative "../../test_helper"

module X
  module Objects
    class APILookupTest < Minitest::Test
      cover API

      def setup
        @client = FakeClient.new
      end

      def test_find_user
        @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "1", "username" => "sferik"}})
        user = @client.find_user("sferik", "user.fields": "id")

        assert_equal "sferik", user.username
        assert_same @client, user.client
        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_find_users
        @client.stub(:get, "users", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal %w[1 2], @client.find_users([1, 2], "user.fields": "id").map(&:id)
        assert_equal "1,2", @client.queries.first["ids"]
        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_me
        @client.stub(:get, "users/me", {"data" => {"id" => "1"}})

        assert_equal "1", @client.me("user.fields": "id").id
        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_find_post
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.find_post(1, "tweet.fields": "id").text
        assert_equal "id", @client.queries.first["tweet.fields"]
      end

      def test_find_posts
        @client.stub(:get, "tweets", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal %w[1 2], @client.find_posts([1, 2], "tweet.fields": "id").map(&:id)
        assert_equal "1,2", @client.queries.first["ids"]
        assert_equal "id", @client.queries.first["tweet.fields"]
      end

      def test_tweet_alias
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.tweet(1).text
      end

      def test_tweets_alias
        @client.stub(:get, "tweets", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal %w[1 2], @client.tweets([1, 2]).map(&:id)
      end

      def test_search
        cursor = @client.search("ruby", max_results: 10)

        assert_equal "tweets/search/recent", cursor.path
        assert_equal "ruby", cursor.params["query"]
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end

      def test_search_all
        cursor = @client.search_all("ruby", max_results: 10)

        assert_equal "tweets/search/all", cursor.path
        assert_equal "ruby", cursor.params["query"]
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end

      def test_find_list
        @client.stub(:get, "lists/1", {"data" => {"id" => "1", "name" => "Ruby"}})

        assert_equal "Ruby", @client.find_list(1, "list.fields": "id").name
        assert_equal "id", @client.queries.first["list.fields"]
      end

      def test_find_space
        @client.stub(:get, "spaces/1", {"data" => {"id" => "1", "title" => "Ruby"}})

        assert_equal "Ruby", @client.find_space("1", "space.fields": "id").title
        assert_equal "id", @client.queries.first["space.fields"]
      end

      def test_direct_messages
        cursor = @client.direct_messages(max_results: 10)

        assert_equal "dm_events", cursor.path
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end
    end
  end
end
