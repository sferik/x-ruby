require_relative "../../test_helper"

module X
  class UserActionsTest < Minitest::Test
    cover Objects::Relationships

    def setup
      @client = FakeClient.new
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_follow
      @client.stub(:post, "users/9/following", {"data" => {"following" => true, "pending_follow" => false}})

      assert @me.follow(User.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/following", query: {}, body: {target_user_id: "1"}.to_json}], @client.requests
    end

    def test_follow_pending
      @client.stub(:post, "users/9/following", {"data" => {"following" => false, "pending_follow" => true}})

      refute @me.follow(1)
    end

    def test_follow_without_body
      @client.stub(:post, "users/9/following", nil)

      assert_same false, @me.follow("1")
    end

    def test_unfollow
      @client.stub(:delete, "users/9/following/1", {"data" => {"following" => false}})

      assert @me.unfollow(User.new({"id" => "1"}))
      assert_equal ["users/9/following/1"], @client.paths
    end

    def test_unfollow_still_following
      @client.stub(:delete, "users/9/following/1", {"data" => {"following" => true}})

      refute @me.unfollow("1")
    end

    def test_unfollow_without_body
      @client.stub(:delete, "users/9/following/1", nil)

      refute @me.unfollow("1")
    end

    def test_like
      @client.stub(:post, "users/9/likes", {"data" => {"liked" => true}})

      assert @me.like(Post.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/likes", query: {}, body: {tweet_id: "1"}.to_json}], @client.requests
    end

    def test_like_not_liked
      @client.stub(:post, "users/9/likes", {"data" => {"liked" => false}})

      refute @me.like(1)
    end

    def test_like_without_body
      @client.stub(:post, "users/9/likes", nil)

      assert_same false, @me.like("1")
    end

    def test_unlike
      @client.stub(:delete, "users/9/likes/1", {"data" => {"liked" => false}})

      assert @me.unlike(Post.new({"id" => "1"}))
      assert_equal ["users/9/likes/1"], @client.paths
    end

    def test_unlike_still_liked
      @client.stub(:delete, "users/9/likes/1", {"data" => {"liked" => true}})

      refute @me.unlike("1")
    end

    def test_bookmark
      @client.stub(:post, "users/9/bookmarks", {"data" => {"bookmarked" => true}})

      assert @me.bookmark(Post.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/bookmarks", query: {}, body: {tweet_id: "1"}.to_json}], @client.requests
    end

    def test_bookmark_not_bookmarked
      @client.stub(:post, "users/9/bookmarks", {"data" => {"bookmarked" => false}})

      refute @me.bookmark(1)
    end

    def test_unbookmark
      @client.stub(:delete, "users/9/bookmarks/1", {"data" => {"bookmarked" => false}})

      assert @me.unbookmark(Post.new({"id" => "1"}))
      assert_equal ["users/9/bookmarks/1"], @client.paths
    end

    def test_unbookmark_still_bookmarked
      @client.stub(:delete, "users/9/bookmarks/1", {"data" => {"bookmarked" => true}})

      refute @me.unbookmark("1")
    end
  end
end
