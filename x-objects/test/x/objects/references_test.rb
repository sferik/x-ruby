# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class ReferencesTest < Minitest::Test
      cover References

      def setup
        includes = Includes.new({"posts" => [{"id" => "5", "text" => "parent"}]})
        @post = Post.new({"id" => "1", "referenced_posts" => [{"type" => "replied_to", "id" => "5"}, {"type" => "quoted", "id" => "6"}]},
          includes:)
        @repost = Post.new({"id" => "2", "referenced_posts" => [{"type" => "reposted", "id" => "4"}]})
        @plain = Post.new({"id" => "3"})
      end

      def test_references
        assert_equal [Post.new({"id" => "5"}), Post.new({"id" => "6"})], @post.references
        assert_equal "parent", @post.references.first.text
        assert_predicate @post.references, :frozen?
        assert_empty @plain.references
      end

      def test_references_share_identity
        assert_same @post.references.last, @post.references.last
        assert_same @post.replied_to, @post.references.first
      end

      def test_references_skip_those_without_id
        post = Post.new({"id" => "1", "referenced_posts" => [{"type" => "quoted"}, {"type" => "quoted", "id" => "6"}]})

        assert_equal [6], post.references.map(&:id)
      end

      def test_replied_to
        assert_equal "parent", @post.replied_to.text
        assert_same @post.replied_to, @post.replied_to
        assert_predicate @post, :reply?
      end

      def test_quoted
        assert_equal Post.new({"id" => "6"}), @post.quoted
        assert_predicate @post, :quote?
      end

      def test_replied_to_and_quoted_are_distinct
        assert_equal [5, 6], [@post.replied_to.id, @post.quoted.id]
      end

      def test_reposted
        assert_equal Post.new({"id" => "4"}), @repost.reposted
        assert_same @repost.reposted, @repost.retweeted
        assert_predicate @repost, :repost?
        assert_predicate @repost, :retweet?
      end

      def test_reposted_under_the_documented_type
        repost = Post.new({"id" => "2", "referenced_posts" => [{"type" => "quoted", "id" => "3"}, {"type" => "retweeted", "id" => "4"}]})

        assert_equal 4, repost.reposted.id
        assert_predicate repost, :repost?
      end

      def test_not_a_repost
        assert_nil @post.reposted
        refute_predicate @post, :repost?
      end

      def test_not_a_reply_or_quote
        assert_nil @plain.replied_to
        assert_nil @plain.quoted
        refute_predicate @plain, :reply?
        refute_predicate @plain, :quote?
      end

      def test_references_without_type_are_ignored
        post = Post.new({"id" => "1", "referenced_posts" => [{"id" => "5"}, {"type" => "quoted", "id" => "6"}]})

        assert_equal 6, post.quoted.id
        assert_nil post.replied_to
      end

      def test_reference_of_type_without_id
        assert_nil Post.new({"id" => "1", "referenced_posts" => [{"type" => "quoted"}]}).quoted
      end
    end
  end
end
