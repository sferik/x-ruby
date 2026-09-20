# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostLookupTest < Minitest::Test
    cover Post

    def setup
      @client = FakeClient.new
    end

    def test_search
      @client.stub(:get, "tweets/search/recent", {"data" => [{"id" => "1", "text" => "ruby"}]})
      cursor = Post.search("ruby -is:retweet", client: @client, max_results: 10)

      assert_equal "tweets/search/recent", cursor.path
      assert_equal "ruby -is:retweet", cursor.params["query"]
      assert_equal 10, cursor.params["max_results"]
      assert_equal ["ruby"], cursor.map(&:text)
    end

    def test_search_defaults
      cursor = Post.search("ruby", client: @client)

      assert_equal Post, cursor.resource_class
      assert_equal 100, cursor.params["max_results"]
      assert_equal Post::FIELDS.join(","), cursor.params["post.fields"]
      assert_same @client, cursor.client
    end

    def test_search_all
      cursor = Post.search_all("ruby", client: @client, max_results: 500)

      assert_equal "tweets/search/all", cursor.path
      assert_equal "ruby", cursor.params["query"]
      assert_equal 500, cursor.params["max_results"]
    end

    def test_search_all_defaults
      cursor = Post.search_all("ruby", client: @client)

      assert_equal Post, cursor.resource_class
      assert_equal 100, cursor.params["max_results"]
      assert_equal Post::FIELDS.join(","), cursor.params["post.fields"]
      assert_same @client, cursor.client
    end

    def test_search_all_pages_by_500_without_context_annotations
      assert_equal [500, 500, 500], [{"post.fields": %w[id text]}, {"post.fields" => "id,text"}, {"post.fields": nil}]
        .map { |params| Post.search_all("ruby", client: @client, **params).params["max_results"] }
    end

    def test_search_all_pages_by_100_with_context_annotations
      assert_equal 100, Post.search_all("ruby", client: @client, "post.fields": %w[context_annotations text]).params["max_results"]
      assert_equal 100, Post.search_all("ruby", client: @client, "post.fields": "id,context_annotations").params["max_results"]
    end

    def test_search_all_does_not_mistake_a_similar_field_for_context_annotations
      assert_equal 500, Post.search_all("ruby", client: @client, "post.fields": "context_annotations_v2").params["max_results"]
    end

    def test_create
      @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "Hello"}})
      post = Post.create("Hello", client: @client, reply: {in_reply_to_tweet_id: "2"})

      assert_equal "Hello", post.text
      refute_predicate post, :hydrated?
      assert_same @client, post.client
      assert_equal({text: "Hello", reply: {in_reply_to_tweet_id: "2"}}.to_json, @client.requests.first[:body])
    end

    def test_create_path
      @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "Hello"}})
      Post.create("Hello", client: @client)

      assert_equal [{method: :post, path: "tweets", query: {}, body: {text: "Hello"}.to_json}], @client.requests
    end

    def test_create_without_data
      @client.stub(:post, "tweets", {"errors" => []})

      assert_nil Post.create("Hello", client: @client)
    end

    def test_delete
      @client.stub(:delete, "tweets/1", {"data" => {"deleted" => true}})

      assert Post.delete(Post.new({"id" => "1"}), client: @client)
      assert Post.delete("1", client: @client)
      assert_equal %w[tweets/1 tweets/1], @client.paths
    end

    def test_delete_not_deleted
      @client.stub(:delete, "tweets/1", {"data" => {"deleted" => false}})

      refute Post.delete(1, client: @client)
    end
  end
end
