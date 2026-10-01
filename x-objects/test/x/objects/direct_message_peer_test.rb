# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class DirectMessagePeerTest < Minitest::Test
    cover DirectMessage

    def setup
      @client = FakeClient.new
      @includes = Objects.const_get(:Includes).new({"users" => [{"id" => "9", "username" => "me"}, {"id" => "8", "username" => "friend"}]})
    end

    def test_from
      message = DirectMessage.new({"id" => "1", "sender_id" => "9"})

      assert_equal [true, true, true, false], [message.from?("9"), message.from?(9), message.from?(User.new({"id" => "9"})), message.from?("8")]
    end

    def test_from_is_false_without_a_sender
      assert_same false, DirectMessage.new({"id" => "1", "dm_conversation_id" => "8-9"}).from?("9")
    end

    def test_from_refuses_what_is_not_a_user_without_a_sender
      assert_raises(ArgumentError) { DirectMessage.new({"id" => "1"}).from?(nil) }
    end

    def test_peer_of_a_received_message_is_the_sender
      message = DirectMessage.__send__(:build, {"id" => "1", "sender_id" => "8", "dm_conversation_id" => "8-9"}, includes: @includes)

      assert_equal "friend", message.peer(User.new({"id" => "9"})).username
      assert_equal "friend", message.peer(9).username
      assert_equal "friend", message.peer("9").username
    end

    def test_peer_of_a_received_message_is_the_sender_whatever_the_conversation
      message = DirectMessage.__send__(:build, {"id" => "1", "sender_id" => "8"}, includes: @includes)

      assert_equal "friend", message.peer("9").username
      assert_equal "friend", DirectMessage.__send__(:build, {"id" => "1", "sender_id" => "8", "dm_conversation_id" => "7-9"}, includes: @includes).peer("9").username
    end

    def test_peer_of_a_sent_message_is_the_other_participant
      message = DirectMessage.__send__(:build, {"id" => "1", "sender_id" => "9", "dm_conversation_id" => "9-8"}, includes: @includes)

      assert_equal "friend", message.peer("9").username
      assert_equal "friend", message.peer(9).username
      assert_equal "friend", message.peer(User.new({"id" => "9"})).username
      assert_same message.peer("9"), message.peer("9")
    end

    def test_peer_of_a_sent_message_is_a_stub_when_not_included
      message = DirectMessage.new({"id" => "1", "sender_id" => "9", "dm_conversation_id" => "8-9"}, client: @client)
      peer = message.peer("9")

      assert_equal 8, peer.id
      assert_predicate peer, :stub?
      assert_same @client, peer.client
    end

    def test_peer_without_another_participant
      assert_nil DirectMessage.new({"id" => "1", "sender_id" => "9", "dm_conversation_id" => "9-9"}).peer("9")
      assert_nil DirectMessage.new({"id" => "1", "sender_id" => "9"}).peer("9")
    end

    def test_peer_of_a_group_conversation
      sent = DirectMessage.__send__(:build, {"id" => "1", "sender_id" => "9", "dm_conversation_id" => "1582838223204016129"}, includes: @includes)
      received = DirectMessage.__send__(:build, {"id" => "2", "sender_id" => "8", "dm_conversation_id" => "1582838223204016129"}, includes: @includes)

      assert_nil sent.peer("9")
      assert_nil received.peer("9")
    end

    def test_peer_without_a_sender_is_the_other_member_of_the_conversation
      message = DirectMessage.new({"id" => "1", "dm_conversation_id" => "8-9"}, client: @client)

      assert_equal [8, 9], [message.peer("9").id, message.peer(8).id]
    end

    def test_peer_without_a_sender_of_a_user_outside_the_conversation
      assert_nil DirectMessage.new({"id" => "1", "dm_conversation_id" => "8-9"}).peer("7")
      assert_nil DirectMessage.new({"id" => "1"}).peer("9")
    end

    def test_peer_of_a_sent_message_of_a_user_outside_the_conversation
      assert_nil DirectMessage.new({"id" => "1", "sender_id" => "9", "dm_conversation_id" => "7-8"}).peer("9")
    end

    def test_peer_of_a_new_message_is_the_recipient
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "8-9", "dm_event_id" => "99"}})

      assert_equal 8, DirectMessage.create(8, "hi", client: @client).peer("9").id
    end
  end
end
