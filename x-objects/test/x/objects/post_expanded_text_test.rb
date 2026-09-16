require_relative "../../test_helper"

module X
  class PostExpandedTextTest < Minitest::Test
    cover Post

    LINK = {"url" => "https://t.co/abc", "expanded_url" => "https://github.com/sferik/x-ruby"}.freeze

    def test_urls
      assert_equal [LINK], Post.new({"id" => "1", "entities" => {"urls" => [LINK]}}).urls
      assert_nil Post.new({"id" => "1"}).urls
    end

    def test_expanded_text_replaces_every_link
      post = Post.new({"id" => "1", "text" => "See https://t.co/abc and https://t.co/def",
                       "entities" => {"urls" => [LINK, {"url" => "https://t.co/def", "expanded_url" => "https://x.com"}]}})

      assert_equal "See https://github.com/sferik/x-ruby and https://x.com", post.expanded_text
    end

    def test_expanded_text_replaces_a_repeated_link_everywhere
      post = Post.new({"id" => "1", "text" => "https://t.co/abc https://t.co/abc", "entities" => {"urls" => [LINK]}})

      assert_equal "https://github.com/sferik/x-ruby https://github.com/sferik/x-ruby", post.expanded_text
    end

    def test_expanded_text_keeps_a_link_without_an_expansion
      post = Post.new({"id" => "1", "text" => "See https://t.co/abc", "entities" => {"urls" => [{"url" => "https://t.co/abc"}]}})

      assert_equal "See https://t.co/abc", post.expanded_text
    end

    def test_expanded_text_rejects_a_link_without_a_url
      post = Post.new({"id" => "1", "text" => "hi", "entities" => {"urls" => [{"expanded_url" => "https://x.com"}]}})

      assert_raises(KeyError) { post.expanded_text }
    end

    def test_expanded_text_without_links
      assert_equal "hi", Post.new({"id" => "1", "text" => "hi"}).expanded_text
      assert_nil Post.new({"id" => "1"}).expanded_text
      assert_nil Post.new({"id" => "1", "entities" => {"urls" => [LINK]}}).expanded_text
    end

    def test_expanded_text_uses_only_the_links_of_the_post_itself
      includes = Objects::Includes.new({"posts" => [{"id" => "2", "text" => "See https://t.co/abc", "entities" => {"urls" => [LINK]}}]})
      post = Post.new({"id" => "1", "text" => "RT @sferik: See https://t.co/abc", "referenced_posts" => [{"type" => "reposted", "id" => "2"}]}, includes:)

      assert_equal "RT @sferik: See https://t.co/abc", post.expanded_text
      assert_equal "See https://github.com/sferik/x-ruby", post.reposted.expanded_text
    end
  end
end
