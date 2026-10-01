# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UserRepostTest < Minitest::Test
    cover Objects.const_get(:Relationships)

    def setup
      @client = FakeClient.new
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_repost_returns_the_rest_id_the_api_returned
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => true, "rest_id" => "2"}})

      assert_equal [2, 2], [@me.repost(Post.new({"id" => "1"})), @me.retweet("1")]
      assert_equal [{tweet_id: "1"}.to_json] * 2, @client.requests.map { |request| request[:body] }
    end

    def test_repost_without_a_rest_id
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => true}})

      assert_nil @me.repost("1")
    end

    def test_repost_not_reposted
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => false, "rest_id" => "2"}})

      assert_nil @me.repost("1")
    end

    def test_repost_reported_as_something_other_than_true
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => "true", "rest_id" => "2"}})

      assert_nil @me.repost("1")
    end

    def test_repost_answered_with_no_data
      @client.stub(:post, "users/9/retweets", nil)

      assert_nil @me.repost("1")
    end

    def test_repost_with_a_rest_id_that_is_not_an_identifier
      @client.stub(:post, "users/9/retweets", {"data" => {"retweeted" => true, "rest_id" => "abc"}})

      error = assert_raises(InvalidAttribute) { @me.repost("1") }
      assert_equal 'X::User#repost cannot be read from "abc"', error.message
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
      error = assert_raises(MissingClient) { User.new({"id" => "9"}).like("1") }

      assert_equal "X::User has no client", error.message
    end
  end
end
