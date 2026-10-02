# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The posts the attached media of a post was first posted with are resolved from the includes of the expansion a
  # lookup asks for
  class PostMediaSourceTest < Minitest::Test
    cover Post

    def setup
      @client = FakeClient.new
      includes = Objects.const_get(:Includes).new({"posts" => [{"id" => "5", "text" => "The original"}]})
      @post = Post.__send__(:build, {"id" => "1", "attachments" => {"media_keys" => ["3_9"], "media_source_tweet_id" => %w[5 6]}},
        client: @client, includes:)
    end

    def test_a_lookup_asks_for_the_expansion
      assert_includes Post::EXPANSIONS, "attachments.media_source_tweet"
      assert_includes Post::FIELDS, "attachments"
    end

    def test_the_posts_attached_media_was_first_posted_with
      sources = @post.media_source_posts

      assert_equal [[5, "The original", false], [6, nil, true]], sources.map { |source| [source.id, source.text, source.stub?] }
      assert_same @client, sources.last.client
      assert_predicate sources, :frozen?
      assert_equal sources, @post.media_source_tweets
    end

    def test_a_post_without_them
      assert_empty Post.new({"id" => "1", "attachments" => {"media_keys" => ["3_9"]}}).media_source_posts
      assert_empty Post.new({"id" => "1"}).media_source_tweets
    end

    def test_attachments_that_cannot_be_read_raise
      assert_raises(InvalidAttribute) { Post.new({"id" => "1", "attachments" => {"media_source_tweet_id" => "5"}}).media_source_posts }
    end

    def test_problems_about_them_are_the_problems_of_the_post
      includes = Objects.const_get(:Includes).new({}, problems: [Problem.new({"title" => "Not Found Error", "resource_id" => "6",
                                                                             "parameter" => "attachments.media_source_tweet_id"})])
      post = Post.__send__(:build, {"id" => "1", "attachments" => {"media_source_tweet_id" => ["6"]}}, includes:)

      assert_equal %w[6], post.problems.map(&:resource_id)
    end
  end
end
