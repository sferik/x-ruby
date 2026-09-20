# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostRepostsTest < Minitest::Test
    cover Post
    cover Objects::PostCollections

    def setup
      @client = FakeClient.new
      @post = Post.new({"id" => "1"}, client: @client)
    end

    def test_reposts
      cursor = @post.reposts

      assert_equal ["tweets/1/retweets", Post, 100, 1], [cursor.path, cursor.resource_class, cursor.params["max_results"], cursor.min_results]
      assert_equal Post.default_params["post.fields"].join(","), cursor.params["post.fields"]
      assert_same @client, cursor.client
    end

    def test_reposts_take_query_parameters
      assert_equal 5, @post.reposts(max_results: 5).params["max_results"]
    end

    def test_reposts_page_through_the_reposts
      @client.stub(:get, "tweets/1/retweets", lambda { |query, _|
        query["pagination_token"] ? {"data" => [{"id" => "3"}]} : {"data" => [{"id" => "2"}], "meta" => {"next_token" => "p2"}}
      })

      assert_equal [2, 3], @post.reposts.map(&:id)
    end

    def test_retweets_is_reposts
      assert_equal "tweets/1/retweets", @post.retweets.path
    end
  end
end
