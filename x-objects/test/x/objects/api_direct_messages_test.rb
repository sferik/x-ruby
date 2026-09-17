require_relative "../../test_helper"

module X
  module Objects
    class APIDirectMessagesTest < Minitest::Test
      cover API::Actions::DirectMessages

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      end

      def test_create_direct_message
        @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
        message = @client.create_direct_message("8", "yo", attachments: [])

        assert_equal 2, message.id
        assert_same @client, message.client
        assert_equal({text: "yo", attachments: []}.to_json, @client.requests.first[:body])
      end

      def test_direct_messages_without_text
        sent = {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}}
        @client.stub(:post, "dm_conversations/with/8/messages", sent).stub(:post, "dm_conversations", sent).stub(:post, "dm_conversations/9-8/messages", sent)
        messages = [@client.create_direct_message(8, attachments: [1]), @client.create_group_direct_message([8, 7], attachments: [2]), @client.create_direct_message_in("9-8", attachments: [3])]

        assert_equal [2, 2, 2], messages.map(&:id)
        assert_equal [{attachments: [1]}.to_json, {conversation_type: "Group", participant_ids: %w[8 7], message: {attachments: [2]}}.to_json, {attachments: [3]}.to_json], @client.requests.map { |request| request[:body] }
      end

      def test_delete_direct_message
        @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

        assert @client.delete_direct_message(1)
        assert_equal ["dm_events/1"], @client.paths
      end

      def test_delete_direct_message_not_deleted
        @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => false}})

        refute @client.delete_direct_message(DirectMessage.new({"id" => "1"}))
      end

      def test_create_group_direct_message
        @client.stub(:post, "dm_conversations", {"data" => {"dm_conversation_id" => "1582838223204016129", "dm_event_id" => "2"}})
        message = @client.create_group_direct_message([8, 7], "Hi", attachments: [])

        assert_equal [2, @client], [message.id, message.client]
        assert_equal({conversation_type: "Group", participant_ids: %w[8 7], message: {text: "Hi", attachments: []}}.to_json, @client.requests.last[:body])
      end

      def test_create_direct_message_in
        @client.stub(:post, "dm_conversations/9-8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
        message = @client.create_direct_message_in("9-8", "Hi", attachments: [])

        assert_equal [2, @client], [message.id, message.client]
        assert_equal({text: "Hi", attachments: []}.to_json, @client.requests.last[:body])
      end

      def test_group_dm_aliases
        @client.stub(:post, "dm_conversations", {"data" => {"dm_conversation_id" => "1582838223204016129", "dm_event_id" => "2"}})
        @client.stub(:post, "dm_conversations/9-8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "3"}})

        assert_equal [2, 3], [@client.create_group_dm([8, 7], "Hi").id, @client.create_dm_in("9-8", "Hi").id]
      end

      def test_dm_aliases
        @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
        @client.stub(:delete, "dm_events/2", {"data" => {"deleted" => true}})

        assert_equal 2, @client.create_dm("8", "yo").id
        assert @client.delete_dm(2)
      end
    end
  end
end
