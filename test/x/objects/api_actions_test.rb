require_relative "../../test_helper"

module X
  module Objects
    class APIActionsTest < Minitest::Test
      cover API

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      end

      def test_create_post
        @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "hi"}})
        post = @client.create_post("hi", reply_settings: "following")

        assert_equal "hi", post.text
        assert_same @client, post.client
        assert_equal({text: "hi", reply_settings: "following"}.to_json, @client.requests.first[:body])
      end

      def test_delete_post
        @client.stub(:delete, "tweets/1", {"data" => {"deleted" => true}})

        assert @client.delete_post("1")
        assert_equal ["tweets/1"], @client.paths
      end

      def test_create_tweet_alias
        @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.create_tweet("hi").text
      end

      def test_delete_tweet_alias
        @client.stub(:delete, "tweets/1", {"data" => {"deleted" => true}})

        assert @client.delete_tweet("1")
      end

      def test_create_direct_message
        @client.stub(:post, "dm_conversations/with/8/messages", {"data" => {"dm_conversation_id" => "9-8", "dm_event_id" => "2"}})
        message = @client.create_direct_message(to: "8", text: "yo", attachments: [])

        assert_equal "2", message.id
        assert_same @client, message.client
        assert_equal({text: "yo", attachments: []}.to_json, @client.requests.first[:body])
      end

      def test_follow
        @client.stub(:post, "users/9/following", {"data" => {"following" => true, "pending_follow" => false}})

        assert @client.follow(User.new({"id" => "1"}))
        assert_equal({target_user_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/following", @client.paths.last
      end

      def test_follow_pending
        @client.stub(:post, "users/9/following", {"data" => {"following" => false, "pending_follow" => true}})

        refute @client.follow("1")
      end

      def test_unfollow
        @client.stub(:delete, "users/9/following/1", {"data" => {"following" => false}})

        assert @client.unfollow(1)
        assert_equal "users/9/following/1", @client.paths.last
      end

      def test_unfollow_still_following
        @client.stub(:delete, "users/9/following/1", {"data" => {"following" => true}})

        refute @client.unfollow("1")
      end

      def test_like
        @client.stub(:post, "users/9/likes", {"data" => {"liked" => true}})

        assert @client.like(Post.new({"id" => "1"}))
        assert_equal({tweet_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/likes", @client.paths.last
      end

      def test_like_not_liked
        @client.stub(:post, "users/9/likes", {"data" => {"liked" => false}})

        refute @client.like("1")
      end

      def test_unlike
        @client.stub(:delete, "users/9/likes/1", {"data" => {"liked" => false}})

        assert @client.unlike("1")
        assert_equal "users/9/likes/1", @client.paths.last
      end

      def test_unlike_still_liked
        @client.stub(:delete, "users/9/likes/1", {"data" => {"liked" => true}})

        refute @client.unlike("1")
      end

      def test_current_user_is_memoized
        @client.stub(:post, "users/9/likes", {"data" => {"liked" => true}})
        2.times { @client.like("1") }

        assert_equal ["users/me", "users/9/likes", "users/9/likes"], @client.paths
      end

      def test_current_user_missing
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(KeyError) { @client.like("1") }

        assert_equal "users/me returned no user", error.message
      end
    end
  end
end
