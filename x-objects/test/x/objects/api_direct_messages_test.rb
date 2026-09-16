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

      def test_delete_direct_message
        @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

        assert @client.delete_direct_message(1)
        assert_equal ["dm_events/1"], @client.paths
      end

      def test_delete_direct_message_not_deleted
        @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => false}})

        refute @client.delete_direct_message(DirectMessage.new({"id" => "1"}))
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
