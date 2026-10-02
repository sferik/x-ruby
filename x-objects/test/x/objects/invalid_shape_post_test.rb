# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The text, entities, links, and referenced posts of a post, or of a message, that are not objects or lists where
  # the API documents them to be raise InvalidAttribute where they are read
  class InvalidShapePostTest < Minitest::Test
    cover Objects.const_get(:References)
    cover Objects.const_get(:Shape)
    cover DirectMessage
    cover Post

    def test_a_note_that_is_not_an_object_raises_from_the_text_and_the_entities
      post = Post.new({"id" => "1", "text" => "A long post…", "note_post" => "A long post"})

      assert_equal "X::Post#note_post cannot be read from \"A long post\"", assert_raises(InvalidAttribute) { post.text }.message
      assert_equal "X::Post#note_post cannot be read from \"A long post\"", assert_raises(InvalidAttribute) { post.entities }.message
    end

    def test_entities_that_are_not_an_object_raise
      post = Post.new({"id" => "1", "entities" => "none"})

      assert_equal "X::Post#entities cannot be read from \"none\"", assert_raises(InvalidAttribute) { post.entities }.message
      assert_raises(InvalidAttribute) { post.urls }
    end

    def test_links_that_are_not_a_list_of_objects_raise
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "entities" => {"urls" => "https://t.co/abc"}}).urls }

      assert_equal "X::Post#urls cannot be read from \"https://t.co/abc\"", error.message
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "entities" => {"urls" => ["https://t.co/abc"]}}).urls }

      assert_equal "\"https://t.co/abc\" is not an object", error.cause.message
      assert_raises(InvalidAttribute) { Post.new({"id" => "1", "entities" => {"urls" => [nil]}}).urls }
    end

    def test_a_list_of_objects_is_frozen
      assert_predicate Post.new({"id" => "1", "entities" => {"urls" => [{"url" => "https://t.co/abc"}]}}).urls, :frozen?
      assert_predicate Post.new({"id" => "1"}).urls, :frozen?
    end

    def test_a_referenced_post_that_is_not_an_object_raises
      post = Post.new({"id" => "1", "referenced_posts" => ["2"]})

      assert_equal "X::Post#referenced_posts cannot be read from [\"2\"]", assert_raises(InvalidAttribute) { post.references }.message
      assert_equal "X::Post#referenced_posts cannot be read from [\"2\"]", assert_raises(InvalidAttribute) { post.replied_to }.message
    end

    def test_a_post_a_message_refers_to_that_is_not_an_object_raises
      error = assert_raises(InvalidAttribute) { DirectMessage.new({"id" => "1", "referenced_posts" => [2]}).references }

      assert_equal "X::DirectMessage#referenced_posts cannot be read from [2]", error.message
    end

    def test_referenced_posts_that_are_not_a_list_raise
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "referenced_posts" => {"id" => "2"}}).references }

      assert_equal "X::Post#referenced_posts cannot be read from {\"id\" => \"2\"}", error.message
    end
  end
end
