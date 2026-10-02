# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class CreatedWithoutDataTest < Minitest::Test
      cover Resource
      cover Post
      cover List
      cover DirectMessage
      cover Objects.const_get(:PostWrites)
      cover Objects.const_get(:DirectMessageConversations)

      FORBIDDEN = {"errors" => [{"title" => "Forbidden", "detail" => "You are not permitted."}, {"title" => "Not Found Error"}]}.freeze

      def setup
        @client = FakeClient.new
      end

      def test_created_from_response_builds_the_resource
        user = User.__send__(:created_from_response, {"data" => {"id" => "1"}}, "POST users", client: @client)

        assert_equal 1, user.id
        assert_same @client, user.client
        refute_predicate user, :hydrated?
      end

      def test_created_from_response_without_data_raises_with_the_problems_of_the_response
        error = assert_raises(MissingResource) { User.__send__(:created_from_response, FORBIDDEN, "POST users", client: @client) }

        assert_equal "POST users returned no X::User: You are not permitted.", error.message
        assert_equal ["Forbidden", "Not Found Error"], error.problems.map(&:title)
      end

      def test_created_from_response_with_nil_body_raises_without_problems
        error = assert_raises(MissingResource) { List.__send__(:created_from_response, nil, "POST lists", client: @client) }

        assert_equal "POST lists returned no X::List", error.message
        assert_empty error.problems
      end

      def test_create_post_without_data
        @client.stub(:post, "tweets", FORBIDDEN)

        error = assert_raises(MissingResource) { Post.create("Hello", client: @client) }

        assert_equal "POST tweets returned no X::Post: You are not permitted.", error.message
        assert_equal ["Forbidden", "Not Found Error"], error.problems.map(&:title)
        assert_raises(MissingResource) { @client.create_post("Hello") }
      end

      def test_create_post_with_nil_body
        @client.stub(:post, "tweets", nil)

        error = assert_raises(MissingResource) { Post.create("Hello", client: @client) }

        assert_equal "POST tweets returned no X::Post", error.message
        assert_empty error.problems
      end

      def test_create_list_without_data
        @client.stub(:post, "lists", FORBIDDEN)

        error = assert_raises(MissingResource) { List.create("Rubyists", client: @client) }

        assert_equal "POST lists returned no X::List: You are not permitted.", error.message
        assert_equal ["Forbidden", "Not Found Error"], error.problems.map(&:title)
        assert_raises(MissingResource) { @client.create_list("Rubyists") }
      end

      def test_create_direct_message_without_data
        @client.stub(:post, "dm_conversations/with/8/messages", FORBIDDEN)

        error = assert_raises(MissingResource) { DirectMessage.create("8", "yo", client: @client) }

        assert_equal "POST dm_conversations/with/8/messages returned no X::DirectMessage: You are not permitted.", error.message
        assert_equal ["Forbidden", "Not Found Error"], error.problems.map(&:title)
        assert_raises(MissingResource) { @client.create_dm("8", "yo") }
      end

      def test_create_direct_message_with_array_data
        @client.stub(:post, "dm_conversations/with/8/messages", {"data" => []})

        assert_raises(MissingResource) { DirectMessage.create("8", "yo", client: @client) }
      end

      def test_create_direct_message_with_nil_body
        @client.stub(:post, "dm_conversations/with/8/messages", nil)

        error = assert_raises(MissingResource) { DirectMessage.create("8", "yo", client: @client) }

        assert_equal "POST dm_conversations/with/8/messages returned no X::DirectMessage", error.message
        assert_empty error.problems
      end

      def test_create_direct_message_in_without_data
        @client.stub(:post, "dm_conversations/9-8/messages", FORBIDDEN)

        error = assert_raises(MissingResource) { DirectMessage.create_in("9-8", "Hi", client: @client) }

        assert_equal "POST dm_conversations/9-8/messages returned no X::DirectMessage: You are not permitted.", error.message
        assert_raises(MissingResource) { @client.create_dm_in("9-8", "Hi") }
      end

      def test_create_group_direct_message_without_data
        @client.stub(:post, "dm_conversations", FORBIDDEN)

        error = assert_raises(MissingResource) { DirectMessage.create_group([8], "Hi", client: @client) }

        assert_equal "POST dm_conversations returned no X::DirectMessage: You are not permitted.", error.message
        assert_raises(MissingResource) { @client.create_group_dm([8], "Hi") }
      end
    end
  end
end
