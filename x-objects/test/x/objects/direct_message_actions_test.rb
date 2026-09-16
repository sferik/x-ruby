require_relative "../../test_helper"

module X
  class DirectMessageActionsTest < Minitest::Test
    cover DirectMessage

    def setup
      @client = FakeClient.new
      @includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "me"}, {"id" => "8", "username" => "friend"}]})
    end

    def test_fields_key
      assert_equal "dm_event.fields", DirectMessage.fields_key
    end

    def test_delete
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert DirectMessage.delete(DirectMessage.new({"id" => "1"}), client: @client)
      assert DirectMessage.delete(1, client: @client)
      assert_equal %w[dm_events/1 dm_events/1], @client.paths
    end

    def test_delete_reports_only_true
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => "yes"}})

      refute DirectMessage.delete("1", client: @client)
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert_same true, DirectMessage.delete("1", client: @client)
    end

    def test_delete_not_deleted
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => false}})

      refute DirectMessage.delete("1", client: @client)
    end

    def test_delete_without_body
      @client.stub(:delete, "dm_events/1", nil)

      refute DirectMessage.delete("1", client: @client)
    end

    def test_delete_instance
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert DirectMessage.new({"id" => "1"}, client: @client).delete
      assert_equal ["dm_events/1"], @client.paths
    end

    def test_delete_without_client
      assert_raises(ArgumentError) { DirectMessage.new({"id" => "1"}).delete }
    end

    def test_from
      message = DirectMessage.new({"id" => "1", "sender_id" => "9"})

      assert message.from?("9")
      assert message.from?(9)
      assert message.from?(User.new({"id" => "9"}))
      refute message.from?("8")
      refute DirectMessage.new({"id" => "1"}).from?("9")
    end

    def test_peer_of_a_received_message_is_the_sender
      message = DirectMessage.new({"id" => "1", "sender_id" => "8", "dm_conversation_id" => "8-9"}, includes: @includes)

      assert_equal "friend", message.peer(User.new({"id" => "9"})).username
      assert_equal "friend", message.peer(9).username
      assert_equal "friend", message.peer("9").username
    end

    def test_peer_of_a_received_message_is_the_sender_whatever_the_conversation
      message = DirectMessage.new({"id" => "1", "sender_id" => "8"}, includes: @includes)

      assert_equal "friend", message.peer("9").username
      assert_equal "friend", DirectMessage.new({"id" => "1", "sender_id" => "8", "dm_conversation_id" => "7-9"}, includes: @includes).peer("9").username
    end

    def test_peer_of_a_sent_message_is_the_other_participant
      message = DirectMessage.new({"id" => "1", "sender_id" => "9", "dm_conversation_id" => "9-8"}, includes: @includes)

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
      assert_nil DirectMessage.new({"id" => "1", "sender_id" => "9", "dm_conversation_id" => "9"}).peer("9")
      assert_nil DirectMessage.new({"id" => "1", "sender_id" => "9"}).peer("9")
    end

    def test_peer_without_a_sender
      assert_nil DirectMessage.new({"id" => "1", "dm_conversation_id" => "8-9"}).peer("9")
    end
  end
end
