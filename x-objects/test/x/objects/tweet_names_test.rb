# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class TweetNamesTest < Minitest::Test
    cover Objects.const_get(:Attributes)
    cover Objects.const_get(:Shape)
    cover Objects.const_get(:Includes)
    cover Post
    cover User
    cover Objects.const_get(:UserCollections)
    cover DirectMessage

    POST = {"id" => "1", "text" => "short…", "author_id" => "9", "edit_history_tweet_ids" => ["1"],
            "note_tweet" => {"text" => "the whole text"}, "referenced_tweets" => [{"type" => "quoted", "id" => "2"}],
            "public_metrics" => {"retweet_count" => 4}}.freeze
    INCLUDES = {"tweets" => [{"id" => "2", "text" => "quoted"}],
                "users" => [{"id" => "9", "pinned_tweet_id" => "2", "most_recent_tweet_id" => "3",
                             "public_metrics" => {"tweet_count" => 12}}]}.freeze

    def setup
      @post = Post.__send__(:resource_from_response, {"data" => POST, "includes" => INCLUDES}, client: FakeClient.new)
    end

    def test_a_post_reads_the_tweet_names
      assert_equal ["the whole text", 4, 4, [1]], [@post.text, @post.repost_count, @post.retweet_count, @post.edit_history_post_ids]
      assert_equal({"text" => "the whole text"}, @post.note_post)
    end

    def test_a_post_resolves_the_tweets_it_refers_to
      assert_predicate @post, :quote?
      assert_equal "quoted", @post.quoted.text
    end

    def test_a_user_reads_the_tweet_names
      author = @post.author

      assert_equal [12, 2, 3, 2, 3], [author.post_count, author.pinned_post_id, author.most_recent_post_id, author.pinned_post.id, author.most_recent_post.id]
      assert_equal "quoted", author.pinned_post.text
    end

    def test_the_post_names_are_read_first
      post = Post.new({"id" => "1", "referenced_posts" => [{"type" => "quoted", "id" => "5"}], "referenced_tweets" => [{"type" => "quoted", "id" => "6"}],
                       "public_metrics" => {"repost_count" => 1, "retweet_count" => 2}})

      assert_equal [5, 1], [post.quoted.id, post.repost_count]
    end

    def test_the_posts_of_the_includes_are_read_first
      body = {"data" => POST, "includes" => {"posts" => [{"id" => "2", "text" => "post"}], "tweets" => [{"id" => "2", "text" => "tweet"}]}}

      assert_equal "post", Post.__send__(:resource_from_response, body, client: FakeClient.new).quoted.text
    end

    def test_a_direct_message_reads_the_tweets_it_refers_to
      message = DirectMessage.new({"id" => "1", "referenced_tweets" => [{"id" => "2"}]})

      assert_equal [{"id" => "2"}], message.referenced_posts
    end

    def test_an_attribute_and_a_reference_declared_with_a_tweet_key_read_it
      klass = Class.new(Resource) do
        attribute :count, :integer, key: %w[metrics post_count], tweet_key: %w[metrics tweet_count]
        reference :pinned, :Post, key: %w[pinned_post_id], tweet_key: %w[pinned_tweet_id]
      end
      resource = klass.new({"id" => "1", "metrics" => {"tweet_count" => "3"}, "pinned_tweet_id" => "2"})

      assert_equal [3, 2], [resource.count, resource.pinned.id]
    end

    def test_a_post_that_names_neither_reads_nothing
      post = Post.new({"id" => "1"})

      assert_equal [nil, [], []], [post.repost_count, post.edit_history_post_ids, post.referenced_posts]
    end
  end
end
