require_relative "../../test_helper"

module X
  class PostAttributesTest < Minitest::Test
    cover Post

    ATTRS = {"id" => "1", "text" => "hi", "lang" => "en", "source" => "app", "created_at" => "2024-01-02T03:04:05.000Z",
             "author_id" => "9", "conversation_id" => "5", "in_reply_to_user_id" => "8", "possibly_sensitive" => false,
             "reply_settings" => "everyone", "edit_history_post_ids" => ["1"], "edit_controls" => {"editable_until" => "x"},
             "entities" => {"urls" => []}, "context_annotations" => [{"domain" => {}}],
             "referenced_posts" => [{"type" => "replied_to", "id" => "5"}],
             "attachments" => {"media_keys" => ["3_1"], "poll_ids" => ["7"]}, "geo" => {"place_id" => "p1"},
             "withheld" => {"copyright" => true}, "note_post" => {"text" => "long"},
             "public_metrics" => {"repost_count" => 1, "reply_count" => 2, "like_count" => 3, "quote_count" => 4,
                                  "bookmark_count" => 5, "impression_count" => 6}}.freeze

    def setup
      @post = Post.new(ATTRS)
    end

    def test_coordinates
      assert_equal [-122.4, 37.8], Post.new({"id" => "1", "geo" => {"coordinates" => {"type" => "Point", "coordinates" => [-122.4, 37.8]}}}).coordinates
      assert_nil Post.new({"id" => "1", "geo" => {"place_id" => "p"}}).coordinates
      assert_nil Post.new({"id" => "1"}).coordinates
    end

    def test_class_configuration
      assert_equal "tweets", Post.endpoint
      assert_equal "posts", Post.includes_key
      assert_same Post, Tweet
    end

    def test_default_params
      expected = {"post.fields" => Post::FIELDS, "user.fields" => User::FIELDS, "media.fields" => Media::FIELDS,
                  "poll.fields" => Poll::FIELDS, "place.fields" => Place::FIELDS, "expansions" => Post::EXPANSIONS}

      assert_equal expected, Post.default_params
    end

    def test_attributes
      assert_equal "hi", @post.text
      assert_equal "en", @post.lang
      assert_equal "app", @post.source
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @post.created_at
      assert_equal 9, @post.author_id
    end

    def test_more_attributes
      assert_equal 5, @post.conversation_id
      assert_equal 8, @post.in_reply_to_user_id
      assert_equal "everyone", @post.reply_settings
      assert_equal [1], @post.edit_history_post_ids
      assert_equal({"editable_until" => "x"}, @post.edit_controls)
    end

    def test_hash_attributes
      assert_equal({"urls" => []}, @post.entities)
      assert_equal([{"domain" => {}}], @post.context_annotations)
      assert_equal({"media_keys" => ["3_1"], "poll_ids" => ["7"]}, @post.attachments)
      assert_equal({"place_id" => "p1"}, @post.geo)
      assert_equal({"copyright" => true}, @post.withheld)
    end

    def test_note_and_metrics_hash
      assert_equal({"text" => "long"}, @post.note_post)
      assert_equal 1, @post.public_metrics["repost_count"]
      assert_equal [{"type" => "replied_to", "id" => "5"}], @post.referenced_posts
      assert_equal @post.referenced_posts, @post.referenced_tweets
    end

    def test_possibly_sensitive
      refute @post.possibly_sensitive
      refute_predicate @post, :possibly_sensitive?
      assert_predicate Post.new({"id" => "1", "possibly_sensitive" => true}), :possibly_sensitive?
    end

    def test_metrics
      assert_equal 1, @post.repost_count
      assert_equal 2, @post.reply_count
      assert_equal 3, @post.like_count
      assert_equal 4, @post.quote_count
    end

    def test_tweet_aliases
      assert_equal 1, @post.retweet_count
      assert_equal [1], @post.edit_history_tweet_ids
      assert_equal({"text" => "long"}, @post.note_tweet)
    end

    def test_more_metrics
      assert_equal 5, @post.bookmark_count
      assert_equal 6, @post.impression_count
    end
  end
end
