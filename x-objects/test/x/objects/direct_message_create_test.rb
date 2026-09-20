# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class DirectMessageCreateTest < Minitest::Test
    cover DirectMessage
    cover Objects::DirectMessageConversations

    def setup
      @client = FakeClient.new
    end

    def test_create
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      message = DirectMessage.create(User.new({"id" => "8"}), "yo", client: @client, attachments: [{media_id: "3"}])

      assert_equal 2, message.id
      assert_equal "9-8", message.dm_conversation_id
      assert_same @client, message.client
      refute_predicate message, :hydrated?
      assert_equal({text: "yo", attachments: [{media_id: "3"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_without_text
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})

      assert_equal 2, DirectMessage.create(8, client: @client, attachments: [{media_id: "3"}]).id
      assert_equal({attachments: [{media_id: "3"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_with_media_ids
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      DirectMessage.create(8, "yo", client: @client, media_ids: [{"id" => 3, "media_key" => "3_3"}, "4", 5])

      assert_equal({text: "yo", attachments: [{media_id: "3"}, {media_id: "4"}, {media_id: "5"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_with_one_media_id
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      DirectMessage.create(8, client: @client, media_ids: {"id" => 3})

      assert_equal({attachments: [{media_id: "3"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_refuses_media_ids_beside_attachments
      error = assert_raises(ArgumentError) { DirectMessage.create(8, "yo", client: @client, media_ids: "3", attachments: [{media_id: "3"}]) }

      assert_equal "pass media_ids or attachments, not both", error.message
      assert_empty @client.requests
    end

    def test_create_group_with_media_ids
      @client.stub(:post, "dm_conversations", {"data" => {"dm_conversation_id" => "9", "dm_event_id" => "2"}})
      DirectMessage.create_group([8, 9], client: @client, media_ids: "3")

      assert_equal({conversation_type: "Group", participant_ids: %w[8 9], message: {attachments: [{media_id: "3"}]}}.to_json, @client.requests.first[:body])
    end

    def test_create_group_refuses_media_ids_beside_attachments
      assert_raises(ArgumentError) { DirectMessage.create_group([8], client: @client, media_ids: "3", attachments: []) }
      assert_empty @client.requests
    end

    def test_create_in_with_media_ids
      @client.stub(:post, "dm_conversations/9/messages", {"data" => {"dm_conversation_id" => "9", "dm_event_id" => "2"}})
      DirectMessage.create_in("9", "yo", client: @client, media_ids: 3)

      assert_equal({text: "yo", attachments: [{media_id: "3"}]}.to_json, @client.requests.first[:body])
    end

    def test_create_in_refuses_media_ids_beside_attachments
      assert_raises(ArgumentError) { DirectMessage.create_in("9", client: @client, media_ids: 3, attachments: []) }
      assert_empty @client.requests
    end

    def test_client_methods_take_media_ids
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
      @client.stub(:post, "dm_conversations", {"data" => {"dm_conversation_id" => "9", "dm_event_id" => "2"}})
      @client.stub(:post, "dm_conversations/9/messages", {"data" => {"dm_conversation_id" => "9", "dm_event_id" => "2"}})
      @client.create_dm(8, media_ids: "3")
      @client.create_group_dm([8], media_ids: "3")
      @client.create_dm_in("9", media_ids: "3")

      assert_equal [{media_id: "3"}], JSON.parse(@client.requests.first[:body], symbolize_names: true).fetch(:attachments)
      assert_equal 3, @client.requests.size
    end

    def test_create_without_text_or_any_other_field_is_refused
      assert_raises(ArgumentError) { DirectMessage.create(8, client: @client) }
      assert_empty @client.requests
    end

    def test_create_with_id
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})

      assert_equal 2, DirectMessage.create(8, "yo", client: @client).id
    end

    def test_create_without_data
      @client.stub(:post, "dm_conversations/with/8/messages", {"errors" => []})

      assert_nil DirectMessage.create("8", "yo", client: @client)
    end

    def test_references_skip_those_without_id
      message = DirectMessage.new({"id" => "1", "referenced_posts" => [{}, {"id" => "5"}]})

      assert_equal [5], message.references.map(&:id)
    end

    def test_create_with_array_data
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => []})

      assert_nil DirectMessage.create("8", "yo", client: @client)
    end

    def test_create_accepts_hash_subclasses
      data = Class.new(Hash).new.merge!("dm_conversation_id" => "9-8", "dm_event_id" => "2")
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => data})

      assert_equal 2, DirectMessage.create("8", "yo", client: @client).id
    end

    def test_create_without_conversation_id
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_event_id" => "2"}})

      assert_nil DirectMessage.create("8", "yo", client: @client).dm_conversation_id
    end

    def test_create_without_event_id
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8"}})

      assert_raises(ArgumentError) { DirectMessage.create("8", "yo", client: @client) }
    end

    def test_create_with_nil_body
      @client.stub(:post, "dm_conversations/with/8/messages", nil)

      assert_nil DirectMessage.create("8", "yo", client: @client)
    end
  end
end
