# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A field of a new post or direct message named by a String is read as the one named by a Symbol, so it is checked
  # and merged as that one is, and a body never names a field twice
  class StringFieldNamesTest < Minitest::Test
    cover Objects.const_get(:PostWrites)
    cover Objects.const_get(:DirectMessageConversations)
    cover Objects.const_get(:Utils)

    def setup
      @client = FakeClient.new
      @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "Hello"}})
      @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
    end

    def test_create_post_merges_reply_and_media_named_by_strings
      fields = {"reply" => {"in_reply_to_tweet_id" => "9", "exclude_reply_user_ids" => ["1"]}, "media" => {"media_ids" => ["9"]}, "text" => "Hi"}
      Post.create("Hello", client: @client, reply_to: 5, media_ids: [4], **fields)

      assert_equal({text: "Hi", reply: {in_reply_to_tweet_id: "5", exclude_reply_user_ids: ["1"]}, media: {media_ids: ["4"]}}.to_json, @client.requests.first[:body])
    end

    def test_create_dm_refuses_media_ids_beside_attachments_named_by_a_string
      fields = {"attachments" => [{media_id: "4"}]}
      error = assert_raises(ArgumentError) { DirectMessage.create(8, client: @client, media_ids: 3, **fields) }

      assert_equal "pass media_ids or attachments, not both", error.message
      assert_empty @client.requests
    end

    def test_create_dm_sends_a_field_named_by_a_string_once
      fields = {"text" => "hi", "attachments" => [{media_id: "4"}]}
      DirectMessage.create(8, "yo", client: @client, **fields)

      assert_equal({text: "hi", attachments: [{media_id: "4"}]}.to_json, @client.requests.first[:body])
    end
  end
end
