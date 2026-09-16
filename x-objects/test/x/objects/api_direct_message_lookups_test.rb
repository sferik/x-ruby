require_relative "../../test_helper"

module X
  module Objects
    class APIDirectMessageLookupsTest < Minitest::Test
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_find_direct_message
        @client.stub(:get, "dm_events/1", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.find_direct_message(1, "dm_event.fields": "id").text
        assert_equal "id", @client.queries.first["dm_event.fields"]
      end

      def test_direct_messages
        cursor = @client.direct_messages(max_results: 10)

        assert_equal "dm_events", cursor.path
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
      end

      def test_direct_messages_with
        cursor = @client.direct_messages_with(User.new({"id" => "8"}), max_results: 10)

        assert_equal "dm_conversations/with/8/dm_events", cursor.path
        assert_equal 10, cursor.params["max_results"]
        assert_same @client, cursor.client
        assert_equal "dm_conversations/with/8/dm_events", @client.direct_messages_with(8).path
      end

      def test_dm_aliases
        @client.stub(:get, "dm_events/1", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.find_dm(1).text
        assert_equal "hi", @client.find_dm!(1).text
        assert_equal "dm_events", @client.dms.path
        assert_equal "dm_conversations/with/8/dm_events", @client.dms_with(8).path
      end
    end
  end
end
