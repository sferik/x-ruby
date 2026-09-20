require_relative "../../test_helper"

module X
  class DirectMessageCreateMediaTest < Minitest::Test
    cover DirectMessage
    cover Objects::DirectMessageConversations
    cover Objects::Utils

    def setup
      @client = FakeClient.new
    end

    def test_create_without_media_ids_attaches_nothing
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      DirectMessage.create(8, "yo", client: @client)

      assert_equal({text: "yo"}.to_json, @client.requests.first[:body])
    end

    def test_create_with_one_media_id_attaches_it
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      DirectMessage.create(8, client: @client, media_ids: 3)

      assert_equal({attachments: [{media_id: "3"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_with_no_media_ids_attaches_nothing
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      DirectMessage.create(8, "yo", client: @client, media_ids: [])

      assert_equal({text: "yo"}.to_json, @client.requests.first[:body])
    end

    def test_create_with_no_media_ids_and_no_text_is_refused
      assert_raises(ArgumentError) { DirectMessage.create(8, client: @client, media_ids: []) }
      assert_empty @client.requests
    end
  end
end
