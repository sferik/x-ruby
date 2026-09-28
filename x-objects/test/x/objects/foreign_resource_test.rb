# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A resource of another class than the one a method takes the identifier of raises ArgumentError before a request,
  # rather than reach the API as the identifier of a resource of that class
  class ForeignResourceTest < Minitest::Test
    cover Objects::Utils
    cover Resource
    cover Objects::Finders
    cover Objects::BatchFinders
    cover Objects::UserFinders
    cover Media

    MESSAGE = "X::List 42 is not X::User: pass X::User or its identifier"

    def setup
      @client = FakeClient.new
      @user = User.new({"id" => "7505382"}, client: @client)
      @post = Post.new({"id" => "1234"}, client: @client)
      @list = List.new({"id" => "42"}, client: @client)
    end

    def test_a_resource_of_another_class_names_both_classes
      assert_equal MESSAGE, assert_raises(ArgumentError) { Objects::Utils.id_of(@list, User) }.message
      assert_equal "X::Space 1DX is not X::User: pass X::User or its identifier", assert_raises(ArgumentError) { Objects::Utils.id_from(Space.new({"id" => "1DX"}), User) }.message
    end

    def test_a_resource_of_the_class_or_of_a_subclass_of_it_is_taken
      assert_equal "7505382", Objects::Utils.id_of(@user, User)
      assert_equal "7", Objects::Utils.id_of(Class.new(User).new({"id" => "7"}), User)
      assert_equal "7", Objects::Utils.id_from(Class.new(User).new({"id" => "7"}), User)
    end

    def test_an_object_that_is_not_a_resource_is_refused_though_it_answers_id
      record = Struct.new(:id).new(7)
      message = "#{record.inspect} is not an identifier: pass X::Post, an Integer, or a String of digits"

      assert_equal message, assert_raises(ArgumentError) { Objects::Utils.id_of(record, Post) }.message
      assert_equal message, assert_raises(ArgumentError) { Objects::Utils.id_from(record, Post) }.message
    end

    def test_an_identifier_of_a_subclass_of_string_is_taken
      assert_equal "7", Objects::Utils.id_from(Class.new(String).new("7"), Post)
    end

    def test_an_object_that_is_not_a_resource_is_neither_a_raw_identifier_nor_taken_for_an_identifier
      record = Struct.new(:id).new("1DX")

      assert_equal "#{record.inspect} is not an identifier: pass X::Space, or a String of word characters", assert_raises(ArgumentError) { Objects::Utils.id_from(record, Space) }.message
      refute Objects::Utils.id?(record)
    end

    def test_a_client_refuses_to_act_on_an_object_that_is_not_a_resource
      record = Struct.new(:id).new(7)

      assert_refused(-> { @client.find_post(record) }, -> { @client.find_user(record) }, -> { @client.find_all_users([record]) })
    end

    def test_a_lookup_refuses_a_resource_of_another_class
      assert_refused(
        -> { Post.find(@user, client: @client) }, -> { Post.find!(@user, client: @client) },
        -> { Post.find_all([@post, @user], client: @client) }, -> { Space.find(@user, client: @client) },
        -> { @client.find_list(@user) }
      )
    end

    def test_a_lookup_of_users_refuses_a_resource_of_another_class
      assert_refused(
        -> { User.find(@post, client: @client) }, -> { User.find!(@post, client: @client) },
        -> { User.find_all([@post], client: @client) }, -> { User.find_by_id(@post, client: @client) },
        -> { User.find_by_id!(@post, client: @client) }, -> { User.find_all_by_id([@post], client: @client) }
      )
    end

    def test_a_lookup_of_media_refuses_a_resource_of_another_class
      assert_refused(-> { Media.find(@post, client: @client) }, -> { Media.find_all([@post], client: @client) }, -> { Media.from_id(@post) })
    end

    def test_from_id_refuses_a_resource_of_another_class
      assert_equal MESSAGE, assert_raises(ArgumentError) { User.from_id(@list) }.message
      assert_equal @user, User.from_id(@user)
    end

    def test_new_refuses_a_resource_of_another_class_for_an_identifier
      assert_raises(ArgumentError) { User.new({"id" => @post}) }
    end

    private

    # Assert that each call raises ArgumentError, and that none of them made a request
    def assert_refused(*calls)
      calls.each { |call| assert_raises(ArgumentError, &call) }

      assert_empty @client.requests
    end
  end

  # The actions and writes that take the identifier of a resource refuse a resource of another class before a request
  class ForeignResourceActionsTest < Minitest::Test
    cover Objects::Relationships
    cover Objects::PostWrites
    cover Objects::DirectMessageConversations
    cover DirectMessage
    cover List

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @user = User.new({"id" => "7505382"}, client: @client)
      @post = Post.new({"id" => "1234"}, client: @client)
      @list = List.new({"id" => "42"}, client: @client)
    end

    def test_the_actions_on_users_refuse_another_resource
      assert_refused(%i[follow unfollow block unblock mute unmute], @list)
    end

    def test_the_actions_on_posts_refuse_another_resource
      assert_refused(%i[like unlike repost unrepost bookmark unbookmark], @user)
    end

    def test_the_actions_on_lists_refuse_another_resource
      assert_refused(%i[follow_list unfollow_list pin_list unpin_list update_list delete_list], @user)
    end

    def test_the_actions_refuse_an_object_that_is_not_a_resource_though_it_answers_id
      record = Struct.new(:id).new(7)

      assert_refused(%i[follow block mute], record)
      assert_refused(%i[like repost bookmark delete_post], record)
    end

    def test_the_writes_of_a_post_refuse_a_resource_of_another_class
      assert_refused(%i[delete_post hide_reply unhide_reply delete_direct_message], @user)
    end

    def test_the_members_of_a_list_refuse_the_arguments_swapped
      [-> { @client.add_list_member(@user, @list) }, -> { @client.remove_list_member(@user, @list) }, -> { @list.add_member(@post) },
        -> { @list.remove_member(@post) }, -> { @list.member?(@post) }].each { |call| assert_raises(ArgumentError, &call) }

      assert_empty @client.requests
    end

    def test_a_new_post_or_message_refuses_a_resource_of_another_class_to_refer_to
      [-> { Post.create("Hi", client: @client, reply_to: @user) }, -> { Post.create("Hi", client: @client, quote: @user) },
        -> { Post.create("Hi", client: @client, community: @post) }, -> { @client.create_direct_message(@post, "Hi") },
        -> { @client.create_group_direct_message([@user, @post], "Hi") }, -> { @client.direct_messages_with(@post) }].each { |call| assert_raises(ArgumentError, &call) }

      assert_empty @client.requests
    end

    def test_a_message_refuses_a_resource_of_another_class_for_its_sender
      message = DirectMessage.new({"id" => "1", "sender_id" => "7505382", "dm_conversation_id" => "7505382-9"})

      assert_raises(ArgumentError) { message.from?(@post) }
      assert_raises(ArgumentError) { message.peer(@post) }
    end

    def test_follows_refuses_a_resource_of_another_class
      assert_raises(ArgumentError) { @user.follows?(@post) }
      assert_empty @client.requests
    end

    private

    # Assert that each action raises ArgumentError for the resource, and that none of them made a request but the
    # lookup of the authenticated user
    def assert_refused(actions, resource)
      actions.each { |action| assert_raises(ArgumentError, action.to_s) { @client.public_send(action, resource) } }

      assert_empty @client.paths - ["users/me"]
    end
  end
end
