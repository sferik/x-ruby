# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostFieldsTest < Minitest::Test
    cover Post
    cover Resources.const_get(:Shape)

    ATTRS = {"id" => "1", "text" => "@sferik hi https://t.co/a", "display_text_range" => [8, 10],
             "scopes" => {"followers" => true}, "card_uri" => "card://1", "article" => {"title" => "On Ruby"},
             "article_title" => {"text" => "On Ruby"},
             "media_metadata" => [{"media_key" => "3_1", "alt_text" => "a cat"}], "paid_partnership" => true}.freeze

    def setup
      @post = Post.new(ATTRS)
      @bare = Post.new({"id" => "2"})
    end

    def test_the_fields_the_api_added
      assert_equal [8...10, {"followers" => true}, "card://1", {"title" => "On Ruby"}],
        [@post.display_text_range, @post.scopes, @post.card_uri, @post.article]
      assert_equal [{"media_key" => "3_1", "alt_text" => "a cat"}], @post.media_metadata
      assert_equal({"text" => "On Ruby"}, @post.article_title)
    end

    def test_the_display_text_range_reads_the_text_that_is_shown
      assert_equal "hi", @post.attrs["text"][@post.display_text_range]
      assert_equal 0...0, Post.new({"id" => "1", "display_text_range" => [0, 0]}).display_text_range
    end

    def test_a_display_text_range_that_is_not_one
      [[8], [8, 10, 12], [8, "10"], ["8", 10], [-1, 10], [8, -1], [8.0, 10], {"start" => 8}, "89", 8].each do |value|
        error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "display_text_range" => value}).display_text_range }

        assert_equal "X::Post#display_text_range cannot be read from #{value.inspect}", error.message
      end
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "display_text_range" => [8, "10"]}).display_text_range }

      assert_equal "[8, \"10\"] is not the start and end of a range", error.cause.message
    end

    def test_a_paid_partnership
      assert_equal [true, true, false, nil], [@post.paid_partnership?, @post.paid_partnership, @bare.paid_partnership?, @bare.paid_partnership]
    end

    def test_fields_a_response_left_out
      assert_equal [nil, nil, nil, nil, nil, []],
        [@bare.display_text_range, @bare.scopes, @bare.card_uri, @bare.article, @bare.article_title, @bare.media_metadata]
    end

    def test_a_lookup_requests_them
      assert_empty %w[article article_title card_uri display_text_range media_metadata paid_partnership scopes] - Post::FIELDS
    end

    def test_a_lookup_does_not_request_the_deprecated_source
      refute_includes Post::FIELDS, "source"
    end
  end
end
