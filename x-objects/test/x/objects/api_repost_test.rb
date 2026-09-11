require_relative "../../test_helper"

module X
  module Objects
    class APIRepostTest < Minitest::Test
      cover API

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      end

      def test_repost
        @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => true}})

        assert @client.repost("1")
        assert_equal({tweet_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/retweets", @client.paths.last
        assert @client.retweet("1")
      end

      def test_repost_not_reposted
        @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => false}})

        refute @client.repost("1")
      end

      def test_unrepost
        @client.stub(:delete, "users/9/retweets/1", {"data" => {"retweeted" => false}})

        assert @client.unrepost("1")
        assert_equal "users/9/retweets/1", @client.paths.last
        assert @client.unretweet("1")
      end

      def test_unrepost_still_reposted
        @client.stub(:delete, "users/9/retweets/1", {"data" => {"retweeted" => true}})

        refute @client.unrepost("1")
      end
    end
  end
end
