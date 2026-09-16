require_relative "../../test_helper"

module X
  class PostCreateTest < Minitest::Test
    cover Post

    def setup
      @client = FakeClient.new
      @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "Hello"}})
    end

    def test_fields_key
      assert_equal "post.fields", Post.fields_key
    end

    def test_create_with_reply_to
      Post.create("Hello", client: @client, reply_to: Post.new({"id" => "2"}))

      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "2"}}.to_json, @client.requests.first[:body])
    end

    def test_create_with_reply_to_id
      Post.create("Hello", client: @client, reply_to: 2)

      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "2"}}.to_json, @client.requests.first[:body])
    end

    def test_create_with_media_ids
      Post.create("Hello", client: @client, media_ids: [3, "4"])

      assert_equal({text: "Hello", media: {media_ids: %w[3 4]}}.to_json, @client.requests.first[:body])
    end

    def test_create_with_upload_responses_as_media_ids
      Post.create("Hello", client: @client, media_ids: [{"id" => "3", "media_key" => "3_3"}, 4])

      assert_equal({text: "Hello", media: {media_ids: %w[3 4]}}.to_json, @client.requests.first[:body])
    end

    def test_create_in_a_community
      Post.create("Hello", client: @client, community: Community.new({"id" => "7"}))
      Post.create("Hello", client: @client, community: 7)

      assert_equal [{text: "Hello", community_id: "7"}.to_json] * 2, @client.requests.map { |request| request[:body] }
    end

    def test_create_with_reply_to_media_ids_and_params
      Post.create("Hello", client: @client, reply_to: "2", media_ids: ["3"], reply_settings: "following")

      assert_equal({text: "Hello", reply_settings: "following", reply: {in_reply_to_tweet_id: "2"}, media: {media_ids: ["3"]}}.to_json, @client.requests.first[:body])
    end

    def test_create_without_reply_to_or_media_ids
      Post.create("Hello", client: @client)

      assert_equal({text: "Hello"}.to_json, @client.requests.first[:body])
    end
  end
end
