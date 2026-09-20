# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UserRepostTest < Minitest::Test
    cover Objects::Relationships

    def setup
      @client = FakeClient.new
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_repost
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => true}})

      assert @me.repost(Post.new({"id" => "1"}))
      assert @me.retweet("1")
      assert_equal [{tweet_id: "1"}.to_json] * 2, @client.requests.map { |request| request[:body] }
    end

    def test_repost_not_reposted
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => false}})

      refute @me.repost("1")
    end

    def test_unrepost
      @client.stub(:delete, "users/9/retweets/1", {"data" => {"retweeted" => false}})

      assert @me.unrepost(Post.new({"id" => "1"}))
      assert @me.unretweet("1")
      assert_equal ["users/9/retweets/1"] * 2, @client.paths
    end

    def test_unrepost_still_reposted
      @client.stub(:delete, "users/9/retweets/1", {"data" => {"retweeted" => true}})

      refute @me.unrepost("1")
    end

    def test_actions_without_client
      error = assert_raises(ArgumentError) { User.new({"id" => "9"}).like("1") }

      assert_equal "X::User has no client", error.message
    end
  end
end
