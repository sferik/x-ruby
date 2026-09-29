# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostFieldsTest < Minitest::Test
    cover Post

    ATTRS = {"id" => "1", "text" => "@sferik hi https://t.co/a", "display_text_range" => [8, 10],
             "scopes" => {"followers" => true}, "card_uri" => "card://1", "article" => {"title" => "On Ruby"},
             "media_metadata" => [{"media_key" => "3_1", "alt_text" => "a cat"}], "paid_partnership" => true}.freeze

    def setup
      @post = Post.new(ATTRS)
      @bare = Post.new({"id" => "2"})
    end

    def test_the_fields_the_api_added
      assert_equal [[8, 10], {"followers" => true}, "card://1", {"title" => "On Ruby"}],
        [@post.display_text_range, @post.scopes, @post.card_uri, @post.article]
      assert_equal [{"media_key" => "3_1", "alt_text" => "a cat"}], @post.media_metadata
    end

    def test_a_paid_partnership
      assert_equal [true, true, false, nil], [@post.paid_partnership?, @post.paid_partnership, @bare.paid_partnership?, @bare.paid_partnership]
    end

    def test_fields_a_response_left_out
      assert_equal [[], nil, nil, nil, []], [@bare.display_text_range, @bare.scopes, @bare.card_uri, @bare.article, @bare.media_metadata]
    end

    def test_a_lookup_requests_them
      assert_empty %w[article card_uri display_text_range media_metadata paid_partnership scopes] - Post::FIELDS
    end
  end
end
