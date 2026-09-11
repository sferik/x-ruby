require_relative "../../test_helper"

module X
  class DirectMessageTest < Minitest::Test
    cover DirectMessage

    def setup
      @client = FakeClient.new
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}, {"id" => "8"}],
                                        "tweets" => [{"id" => "5", "text" => "shared"}],
                                        "media" => [{"media_key" => "3_1"}]})
      @message = DirectMessage.new({"id" => "1", "text" => "hi", "event_type" => "MessageCreate",
                                    "created_at" => "2024-01-02T03:04:05.000Z", "sender_id" => "9",
                                    "dm_conversation_id" => "9-8", "participant_ids" => %w[9 8],
                                    "referenced_tweets" => [{"id" => "5"}], "attachments" => {"media_keys" => ["3_1"]}},
        client: @client, includes:)
    end

    def test_class_configuration
      assert_equal "dm_events", DirectMessage.endpoint
      assert_nil DirectMessage.includes_key
      expected = {"dm_event.fields" => DirectMessage::FIELDS, "user.fields" => User::FIELDS, "tweet.fields" => Post::FIELDS,
                  "media.fields" => Media::FIELDS, "expansions" => DirectMessage::EXPANSIONS}

      assert_equal expected, DirectMessage.default_params
    end

    def test_attributes
      assert_equal "hi", @message.text
      assert_equal "MessageCreate", @message.event_type
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @message.created_at
      assert_equal "9", @message.sender_id
      assert_equal "9-8", @message.dm_conversation_id
    end

    def test_more_attributes
      assert_equal "9-8", @message.conversation_id
      assert_equal %w[9 8], @message.participant_ids
      assert_equal [{"id" => "5"}], @message.referenced_tweets
      assert_equal({"media_keys" => ["3_1"]}, @message.attachments)
    end

    def test_references
      assert_equal "sferik", @message.sender.username
      assert_equal %w[9 8], @message.participants.map(&:id)
      assert_equal ["3_1"], @message.media.map(&:media_key)
    end

    def test_referenced_posts
      assert_equal ["shared"], @message.referenced_posts.map(&:text)
      assert_same @message.referenced_posts.first, @message.referenced_posts.first
      assert_predicate @message.referenced_posts, :frozen?
      assert_empty DirectMessage.new({"id" => "1"}).referenced_posts
    end

    def test_all
      @client.stub(:get, "dm_events", {"data" => [{"id" => "1", "text" => "hi"}]})
      cursor = DirectMessage.all(client: @client, max_results: 5)

      assert_equal DirectMessage, cursor.klass
      assert_equal "dm_events", cursor.path
      assert_equal 5, cursor.params["max_results"]
      assert_equal ["hi"], cursor.map(&:text)
      assert_same @client, cursor.client
    end

    def test_all_default_max_results
      cursor = DirectMessage.all(client: @client)

      assert_equal 100, cursor.params["max_results"]
      assert_equal DirectMessage::FIELDS.join(","), cursor.params["dm_event.fields"]
    end

    def test_with
      cursor = DirectMessage.with(User.new({"id" => "8"}), client: @client, max_results: 5)

      assert_equal "dm_conversations/with/8/dm_events", cursor.path
      assert_equal DirectMessage, cursor.klass
      assert_equal 5, cursor.params["max_results"]
      assert_equal "dm_conversations/with/8/dm_events", DirectMessage.with(8, client: @client).path
      assert_same @client, cursor.client
    end

    def test_with_default_max_results
      cursor = DirectMessage.with("8", client: @client)

      assert_equal 100, cursor.params["max_results"]
      assert_equal DirectMessage::FIELDS.join(","), cursor.params["dm_event.fields"]
    end
  end
end
