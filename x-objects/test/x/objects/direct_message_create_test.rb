require_relative "../../test_helper"

module X
  class DirectMessageCreateTest < Minitest::Test
    cover DirectMessage

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
