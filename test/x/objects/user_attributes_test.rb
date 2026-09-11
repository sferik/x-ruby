require_relative "../../test_helper"

module X
  class UserAttributesTest < Minitest::Test
    cover User

    ATTRS = {"id" => "1", "name" => "Erik Berlin", "username" => "sferik", "description" => "d",
             "location" => "SF", "url" => "https://t.co/x", "profile_image_url" => "https://pbs.twimg.com/x.jpg",
             "created_at" => "2007-07-16T22:16:23.000Z", "protected" => false, "verified" => true,
             "verified_type" => "blue", "pinned_tweet_id" => "2", "most_recent_tweet_id" => "3",
             "entities" => {"url" => {}}, "withheld" => {"country_codes" => []},
             "public_metrics" => {"followers_count" => 10, "following_count" => 20, "tweet_count" => 30,
                                  "listed_count" => 40, "like_count" => 50}}.freeze

    def setup
      @user = User.new(ATTRS)
    end

    def test_class_configuration
      assert_equal "users", User.endpoint
      assert_equal "users", User.includes_key
      assert_equal({"user.fields" => User::FIELDS, "tweet.fields" => Post::FIELDS, "expansions" => User::EXPANSIONS},
        User.default_params)
    end

    def test_attributes
      assert_equal "Erik Berlin", @user.name
      assert_equal "sferik", @user.username
      assert_equal "d", @user.description
      assert_equal "SF", @user.location
      assert_equal "https://t.co/x", @user.url
    end

    def test_more_attributes
      assert_equal "https://pbs.twimg.com/x.jpg", @user.profile_image_url
      assert_equal Time.utc(2007, 7, 16, 22, 16, 23), @user.created_at
      assert_equal "blue", @user.verified_type
      assert_equal "2", @user.pinned_post_id
      assert_equal "3", @user.most_recent_post_id
    end

    def test_hash_attributes
      assert_equal({"url" => {}}, @user.entities)
      assert_equal({"country_codes" => []}, @user.withheld)
      assert_equal 10, @user.public_metrics["followers_count"]
    end

    def test_predicates
      refute_predicate @user, :protected?
      refute @user.protected
      assert_predicate @user, :verified?
      assert @user.verified
    end

    def test_metrics
      assert_equal 10, @user.followers_count
      assert_equal 20, @user.following_count
      assert_equal 30, @user.post_count
      assert_equal 40, @user.listed_count
      assert_equal 50, @user.like_count
    end

    def test_tweet_aliases
      assert_equal 30, @user.tweet_count
      assert_equal "2", @user.pinned_tweet_id
      assert_equal "3", @user.most_recent_tweet_id
    end

    def test_pinned_post
      assert_equal Post.new({"id" => "2"}), @user.pinned_post
      assert_same @user.pinned_post, @user.pinned_tweet
    end

    def test_most_recent_post
      assert_equal Post.new({"id" => "3"}), @user.most_recent_post
      assert_same @user.most_recent_post, @user.most_recent_tweet
    end
  end
end
