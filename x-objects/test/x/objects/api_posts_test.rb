require_relative "../../test_helper"

module X
  module Objects
    class APIPostsTest < Minitest::Test
      cover API::Actions::Posts

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

      def test_hide_reply
        @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => true}})

        assert @client.hide_reply(Post.new({"id" => "1"}))
        assert_equal({hidden: true}.to_json, @client.requests.last[:body])
      end

      def test_unhide_reply
        @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => false}})

        assert @client.unhide_reply("1")
        assert_equal({hidden: false}.to_json, @client.requests.last[:body])
      end

      def test_create_tweet_alias
        @client.stub(:post, "tweets", {"data" => {"id" => "1", "text" => "hi"}})

        assert_equal "hi", @client.create_tweet("hi").text
      end

      def test_delete_tweet_alias
        @client.stub(:delete, "tweets/1", {"data" => {"deleted" => true}})

        assert @client.delete_tweet("1")
      end
    end
  end
end
