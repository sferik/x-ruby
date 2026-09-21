# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class APILookupTest < Minitest::Test
      cover API::Lookups

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

        assert_equal [1, 2], @client.find_all_users([1, 2], "user.fields": "id").map(&:id)
        assert_equal "1,2", @client.queries.first["ids"]
        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_find_post
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.find_post(1, "post.fields": "id").text
        assert_equal "id", @client.queries.first["post.fields"]
      end

      def test_find_posts
        @client.stub(:get, "tweets", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal [1, 2], @client.find_all_posts([1, 2], "post.fields": "id").map(&:id)
        assert_equal "1,2", @client.queries.first["ids"]
        assert_equal "id", @client.queries.first["post.fields"]
      end

      def test_find_tweet_aliases
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})
        @client.stub(:get, "tweets/2", {"errors" => []})
        @client.stub(:get, "tweets", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal "hi", @client.find_tweet(1).text
        assert_equal "hi", @client.find_tweet!(1).text
        assert_equal [1, 2], @client.find_all_tweets([1, 2]).map(&:id)
        assert_raises(MissingResource) { @client.find_tweet!(2) }
      end

      def test_search_posts
        cursor = @client.search_posts("ruby", max_results: 10)

        assert_equal "tweets/search/recent", cursor.path
        assert_equal "ruby", cursor.params["query"]
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end

      def test_search_is_search_posts
        cursor = @client.search("ruby", max_results: 10)

        assert_equal "tweets/search/recent", cursor.path
        assert_equal "ruby", cursor.params["query"]
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end

      def test_search_all_posts
        cursor = @client.search_all_posts("ruby", max_results: 10)

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

      def test_find_spaces
        @client.stub(:get, "spaces", {"data" => [{"id" => "1"}, {"id" => "2"}]})

        assert_equal %w[1 2], @client.find_all_spaces(["1", "2"], "space.fields": "id").map(&:id)
        assert_equal "1,2", @client.queries.first["ids"]
        assert_equal "id", @client.queries.first["space.fields"]
      end

      def test_search_spaces
        cursor = @client.search_spaces("ruby", state: "scheduled")

        assert_equal ["spaces/search", "ruby", "scheduled"], [cursor.path, cursor.params["query"], cursor.params["state"]]
        assert_same @client, cursor.client
      end

      def test_search_tweet_aliases
        assert_equal "tweets/search/recent", @client.search_tweets("ruby").path
        assert_equal "tweets/search/all", @client.search_all_tweets("ruby").path
        assert_equal "ruby", @client.search_tweets("ruby").params["query"]
        assert_equal "ruby", @client.search_all_tweets("ruby").params["query"]
      end
    end

    # The lookups of media, which the API takes the media keys of rather than identifiers
    class APIMediaLookupTest < Minitest::Test
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_find_media
        @client.stub(:get, "media/3_1", {"data" => {"media_key" => "3_1", "type" => "photo"}})
        problems = []

        assert_equal "photo", @client.find_media("3_1", "media.fields": "type") { |problem| problems << problem }.type
        assert_equal "type", @client.queries.first["media.fields"]
        assert_empty problems
      end

      def test_find_media_passes_each_problem_to_its_block
        @client.stub(:get, "media/3_9", {"errors" => [{"title" => "Not Found Error"}]})
        titles = []

        assert_nil @client.find_media("3_9") { |problem| titles << problem.title }
        assert_equal ["Not Found Error"], titles
      end

      def test_find_all_media
        @client.stub(:get, "media", {"data" => [{"media_key" => "3_1"}], "errors" => [{"title" => "Not Found Error"}]})
        titles = []

        media = @client.find_all_media(%w[3_1 3_9], "media.fields": "type") { |problem| titles << problem.title }

        assert_equal %w[3_1], media.map(&:id)
        assert_equal ["Not Found Error"], titles
        assert_equal ["3_1,3_9", "type"], @client.queries.first.values_at("media_keys", "media.fields")
      end
    end
  end
end
