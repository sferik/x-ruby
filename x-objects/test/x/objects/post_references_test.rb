require_relative "../../test_helper"

module X
  class PostReferencesTest < Minitest::Test
    cover Post
    cover Objects::PostCollections

    def setup
      @client = FakeClient.new
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}],
                                        "media" => [{"media_key" => "3_1", "url" => "https://pbs.twimg.com/1.jpg"}],
                                        "polls" => [{"id" => "7", "voting_status" => "open"}],
                                        "places" => [{"id" => "p1", "name" => "SF"}]})
      @post = Post.new({"id" => "1", "author_id" => "9", "in_reply_to_user_id" => "8",
                        "attachments" => {"media_keys" => ["3_1"], "poll_ids" => ["7"]}, "geo" => {"place_id" => "p1"}},
        client: @client, includes:)
    end

    def test_author_from_includes
      assert_equal "sferik", @post.author.username
      assert_same @post.author, @post.author
    end

    def test_in_reply_to_user_stub
      assert_equal User.new({"id" => "8"}), @post.in_reply_to_user
      refute_predicate @post.in_reply_to_user, :hydrated?
      assert_same @client, @post.in_reply_to_user.client
    end

    def test_place
      assert_equal "SF", @post.place.name
      assert_nil Post.new({"id" => "1"}).place
    end

    def test_media
      assert_equal ["https://pbs.twimg.com/1.jpg"], @post.media.map(&:url)
      assert_empty Post.new({"id" => "1"}).media
    end

    def test_polls
      assert_equal ["open"], @post.polls.map(&:voting_status)
      assert_empty Post.new({"id" => "1"}).polls
    end

    def test_cursor_paths
      assert_equal "tweets/1/liking_users", @post.liked_by.path
      assert_equal "tweets/1/retweeted_by", @post.reposted_by.path
      assert_equal "tweets/1/retweeted_by", @post.retweeted_by.path
      assert_equal "tweets/1/quote_tweets", @post.quotes.path
    end

    def test_cursor_classes
      assert_equal User, @post.liked_by.resource_class
      assert_equal User, @post.reposted_by.resource_class
      assert_equal Post, @post.quotes.resource_class
      assert_same @client, @post.quotes.client
    end

    def test_cursor_max_results
      assert_equal 100, @post.liked_by.params["max_results"]
      assert_equal 100, @post.reposted_by.params["max_results"]
      assert_equal 100, @post.quotes.params["max_results"]
    end

    def test_cursor_params
      assert_equal 5, @post.liked_by(max_results: 5).params["max_results"]
      assert_equal 5, @post.reposted_by(max_results: 5).params["max_results"]
      assert_equal 5, @post.quotes(max_results: 5).params["max_results"]
    end
  end
end
