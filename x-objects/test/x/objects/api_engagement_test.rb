require_relative "../../test_helper"

module X
  module Objects
    class APIEngagementTest < Minitest::Test
      cover API::Actions::Engagement

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
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

      def test_bookmark
        @client.stub(:post, "users/9/bookmarks", {"data" => {"bookmarked" => true}})

        assert @client.bookmark(Post.new({"id" => "1"}))
        assert_equal({tweet_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/bookmarks", @client.paths.last
      end

      def test_bookmark_not_bookmarked
        @client.stub(:post, "users/9/bookmarks", {"data" => {"bookmarked" => false}})

        refute @client.bookmark("1")
      end

      def test_unbookmark
        @client.stub(:delete, "users/9/bookmarks/1", {"data" => {"bookmarked" => false}})

        assert @client.unbookmark("1")
        assert_equal "users/9/bookmarks/1", @client.paths.last
      end

      def test_unbookmark_still_bookmarked
        @client.stub(:delete, "users/9/bookmarks/1", {"data" => {"bookmarked" => true}})

        refute @client.unbookmark("1")
      end

      def test_current_user_is_memoized
        @client.stub(:post, "users/9/likes", {"data" => {"liked" => true}})
        2.times { @client.like("1") }

        assert_equal ["users/me", "users/9/likes", "users/9/likes"], @client.paths
      end

      def test_current_user_missing
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(MissingResource) { @client.like("1") }

        assert_equal "users/me returned no user", error.message
      end
    end
  end
end
