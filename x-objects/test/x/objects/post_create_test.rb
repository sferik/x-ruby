require_relative "../../test_helper"

module X
  class PostCreateTest < Minitest::Test
    cover Post
    cover Objects::PostWrites

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

    def test_create_without_text
      Post.create(client: @client, media_ids: [3])
      Post.create(nil, client: @client, quote: 2)

      assert_equal [{media: {media_ids: ["3"]}}.to_json, {quote_tweet_id: "2"}.to_json], @client.requests.map { |request| request[:body] }
    end

    def test_create_drops_fields_given_nil
      Post.create("Hello", client: @client, reply_settings: nil)

      assert_equal({text: "Hello"}.to_json, @client.requests.first[:body])
    end

    def test_create_without_text_or_any_other_field_is_refused
      error = assert_raises(ArgumentError) { Post.create(client: @client, reply_settings: nil) }

      assert_equal "a post needs text, or something else to show, such as media_ids", error.message
      assert_empty @client.requests
    end

    def test_create_with_upload_responses_as_media_ids
      Post.create("Hello", client: @client, media_ids: [{"id" => "3", "media_key" => "3_3"}, 4])

      assert_equal({text: "Hello", media: {media_ids: %w[3 4]}}.to_json, @client.requests.first[:body])
    end

    def test_create_a_quote
      Post.create("Worth reading", client: @client, quote: Post.new({"id" => "2"}))
      Post.create("Worth reading", client: @client, quote: 2)

      assert_equal [{text: "Worth reading", quote_tweet_id: "2"}.to_json] * 2, @client.requests.map { |request| request[:body] }
    end

    def test_create_a_quote_in_reply_with_media_in_a_community
      Post.create("Hello", client: @client, reply_to: 2, quote: 3, media_ids: [4], community: 5)

      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "2"}, quote_tweet_id: "3", media: {media_ids: ["4"]}, community_id: "5"}.to_json,
        @client.requests.first[:body])
    end

    def test_create_returns_the_post
      post = Post.create("Hello", client: @client)

      assert_equal [1, "Hello", @client], [post.id, post.text, post.client]
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

    def test_create_keeps_the_other_reply_fields_beside_reply_to
      Post.create("Hello", client: @client, reply_to: 5, reply: {exclude_reply_user_ids: ["1"]})

      assert_equal({text: "Hello", reply: {exclude_reply_user_ids: ["1"], in_reply_to_tweet_id: "5"}}.to_json, @client.requests.first[:body])
    end

    def test_create_keeps_the_other_media_fields_beside_media_ids
      Post.create("Hello", client: @client, media_ids: [4], media: {tagged_user_ids: ["2"]})

      assert_equal({text: "Hello", media: {tagged_user_ids: ["2"], media_ids: ["4"]}}.to_json, @client.requests.first[:body])
    end

    def test_reply_to_and_media_ids_win_the_one_field_each_of_them_sets
      Post.create("Hello", client: @client, reply_to: 5, reply: {in_reply_to_tweet_id: "9"}, media_ids: [4], media: {media_ids: ["9"]})

      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "5"}, media: {media_ids: ["4"]}}.to_json, @client.requests.first[:body])
    end

    def test_create_keeps_reply_and_media_given_without_the_convenience_keys
      Post.create("Hello", client: @client, reply: {in_reply_to_tweet_id: "9"}, media: {media_ids: ["9"]})

      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "9"}, media: {media_ids: ["9"]}}.to_json, @client.requests.first[:body])
    end

    def test_create_accepts_one_media_id
      Post.create("Hello", client: @client, media_ids: 4)
      Post.create("Hello", client: @client, media_ids: {"id" => "5"})

      assert_equal [{text: "Hello", media: {media_ids: ["4"]}}.to_json, {text: "Hello", media: {media_ids: ["5"]}}.to_json], @client.requests.map { |request| request[:body] }
    end
  end
end
