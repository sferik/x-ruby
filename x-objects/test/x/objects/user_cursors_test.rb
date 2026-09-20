require_relative "../../test_helper"

module X
  class UserCursorsTest < Minitest::Test
    cover User
    cover X::Objects::UserFinders

    PATHS = {followers: "users/1/followers", following: "users/1/following", blocking: "users/1/blocking",
             muting: "users/1/muting", posts: "users/1/tweets", home_timeline: "users/1/timelines/reverse_chronological",
             mentions: "users/1/mentions", liked_posts: "users/1/liked_tweets", bookmarks: "users/1/bookmarks",
             owned_lists: "users/1/owned_lists", list_memberships: "users/1/list_memberships",
             followed_lists: "users/1/followed_lists"}.freeze
    THOUSANDS = %i[followers following blocking muting].freeze

    def setup
      @client = FakeClient.new
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_cursor_paths
      PATHS.each do |method, path|
        assert_equal path, @user.public_send(method).path, method
      end
    end

    def test_cursor_clients
      PATHS.each_key do |method|
        assert_same @client, @user.public_send(method).client, method
      end
    end

    def test_user_cursors
      THOUSANDS.each do |method|
        assert_equal [User, 1000], [@user.public_send(method).resource_class, @user.public_send(method).params["max_results"]], method
      end
    end

    def test_post_cursor_classes
      assert_equal Post, @user.posts.resource_class
      assert_equal Post, @user.home_timeline.resource_class
      assert_equal Post, @user.mentions.resource_class
      assert_equal Post, @user.liked_posts.resource_class
      assert_equal Post, @user.bookmarks.resource_class
    end

    def test_list_cursor_classes
      assert_equal List, @user.owned_lists.resource_class
      assert_equal List, @user.list_memberships.resource_class
      assert_equal List, @user.followed_lists.resource_class
    end

    def test_reposts_of_me_belongs_to_the_client_rather_than_a_user
      refute_respond_to @user, :reposts_of_me
    end

    def test_default_max_results
      PATHS.each_key do |method|
        assert_equal(THOUSANDS.include?(method) ? 1000 : 100, @user.public_send(method).params["max_results"], method)
      end
    end

    def test_cursor_params
      PATHS.each_key do |method|
        assert_equal 5, @user.public_send(method, max_results: 5).params["max_results"], method
      end
    end

    def test_cursor_aliases
      assert_equal "users/1/tweets", @user.tweets.path
      assert_equal "users/1/liked_tweets", @user.liked_tweets.path
    end
  end
end
