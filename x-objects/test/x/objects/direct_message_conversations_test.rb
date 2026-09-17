require_relative "../../test_helper"

module X
  class DirectMessageConversationsTest < Minitest::Test
    cover Objects::DirectMessageConversations

    SENT = {"data" => {"dm_conversation_id" => "1582838223204016129", "dm_event_id" => "2"}}.freeze

    def setup
      @client = FakeClient.new
    end

    def test_create_group
      @client.stub(:post, "dm_conversations", SENT)
      message = DirectMessage.create_group([User.new({"id" => "8"}), 7], "Hello, both of you!", client: @client, attachments: [{media_id: "3"}])

      assert_equal [2, "1582838223204016129"], [message.id, message.dm_conversation_id]
      assert_same @client, message.client
      assert_equal [{method: :post, path: "dm_conversations", query: {},
                     body: {conversation_type: "Group", participant_ids: %w[8 7], message: {text: "Hello, both of you!", attachments: [{media_id: "3"}]}}.to_json}], @client.requests
    end

    def test_create_group_refuses_a_username
      assert_raises(ArgumentError) { DirectMessage.create_group(%w[sferik 7], "Hi", client: @client) }
      assert_empty @client.requests
    end

    def test_create_in_a_conversation_by_identifier
      @client.stub(:post, "dm_conversations/1582838223204016129/messages", SENT)
      message = DirectMessage.create_in("1582838223204016129", "Sounds good", client: @client, attachments: [])

      assert_equal [2, @client], [message.id, message.client]
      assert_equal [{text: "Sounds good", attachments: []}.to_json], @client.requests.map { |request| request[:body] }
    end

    def test_create_in_the_conversation_of_a_message
      @client.stub(:post, "dm_conversations/9-8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "3"}})

      assert_equal 3, DirectMessage.create_in(DirectMessage.new({"id" => "1", "dm_conversation_id" => "9-8"}), "Hi", client: @client).id
    end

    def test_create_in_without_data
      @client.stub(:post, "dm_conversations/9-8/messages", {"errors" => []})

      assert_nil DirectMessage.create_in("9-8", "Hi", client: @client)
    end

    def test_in
      cursor = DirectMessage.in(DirectMessage.new({"id" => "1", "dm_conversation_id" => "1582838223204016129"}), client: @client, event_types: "MessageCreate")

      assert_equal ["dm_conversations/1582838223204016129/dm_events", DirectMessage, 100, "MessageCreate"],
        [cursor.path, cursor.klass, cursor.params["max_results"], cursor.params["event_types"]]
      assert_same @client, cursor.client
    end

    def test_in_a_group_conversation_by_integer_identifier
      assert_equal "dm_conversations/1582838223204016129/dm_events", DirectMessage.in(1_582_838_223_204_016_129, client: @client).path
    end

    def test_in_takes_a_page_size
      assert_equal 10, DirectMessage.in("9-8", client: @client, max_results: 10).params["max_results"]
    end

    def test_a_conversation_that_is_not_one_is_refused
      error = assert_raises(ArgumentError) { DirectMessage.in("sferik", client: @client) }

      assert_equal "\"sferik\" is not a conversation: pass a direct message or a conversation identifier", error.message
      assert_raises(ArgumentError) { DirectMessage.in(DirectMessage.new({"id" => "1"}), client: @client) }
    end

    def test_a_conversation_identifier_must_be_whole
      %w[9- x9-8 9-8x].each do |conversation|
        assert_raises(ArgumentError) { DirectMessage.create_in(conversation, "Hi", client: @client) }
      end
    end
  end
end
