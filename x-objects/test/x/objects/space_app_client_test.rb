require_relative "../../test_helper"

module X
  class SpaceAppClientTest < Minitest::Test
    cover Space
    cover Cursor
    cover Objects::Finders
    cover Objects::Pages
    cover Objects::Resource

    # A client with an app-only client, as an X::Client that signs with OAuth 1.0a has
    class UserClient < FakeClient
      attr_reader :app

      def initialize
        super
        @app = FakeClient.new
      end

      def app_only = app
    end

    def setup
      @client = UserClient.new
    end

    def test_find_uses_the_app_only_client
      @client.app.stub(:get, "spaces/1DXxyRYNejbKM", {"data" => {"id" => "1DXxyRYNejbKM", "title" => "Ruby"}})

      assert_equal "Ruby", @client.find_space("1DXxyRYNejbKM").title
      assert_equal ["spaces/1DXxyRYNejbKM"], @client.app.paths
      assert_empty @client.requests
    end

    def test_find_bang_uses_the_app_only_client
      @client.app.stub(:get, "spaces/1DXxyRYNejbKM", {"data" => {"id" => "1DXxyRYNejbKM", "title" => "Ruby"}})

      assert_equal "Ruby", @client.find_space!("1DXxyRYNejbKM").title
      assert_equal ["spaces/1DXxyRYNejbKM"], @client.app.paths
      assert_empty @client.requests
    end

    def test_find_all_uses_the_app_only_client
      @client.app.stub(:get, "spaces", ->(query, _) { {"data" => query.fetch("ids").split(",").map { |id| {"id" => id} }} })

      assert_equal %w[1DXxyRYNejbKM 1YpKkgVgevkxj], @client.find_spaces(%w[1DXxyRYNejbKM 1YpKkgVgevkxj]).map(&:id)
      assert_equal ["spaces"], @client.app.paths
      assert_empty @client.requests
    end

    def test_search_uses_the_app_only_client
      @client.app.stub(:get, "spaces/search", {"data" => [{"id" => "1DXxyRYNejbKM", "title" => "Ruby"}], "meta" => {"result_count" => 1}})

      assert_equal ["Ruby"], @client.search_spaces("ruby").map(&:title)
      assert_equal ["spaces/search"], @client.app.paths
      assert_empty @client.requests
    end

    def test_the_spaces_a_search_returns_hold_the_client_given_so_they_act_as_the_user
      @client.app.stub(:get, "spaces/search", {"data" => [{"id" => "1DXxyRYNejbKM", "creator_id" => "7"}], "meta" => {"result_count" => 1}})
      cursor = @client.search_spaces("ruby")

      assert_predicate cursor, :app_only?
      assert_same @client, cursor.client
      assert_same @client, cursor.first.client
      assert_same @client, cursor.first.creator.client
    end

    def test_derived_cursors_keep_fetching_as_the_app
      cursor = @client.search_spaces("ruby")

      assert_equal [true, true, true], [cursor.refresh, cursor.prefetch, cursor.stubs].map(&:app_only?)
    end

    def test_any_other_cursor_fetches_as_the_user_and_so_do_the_cursors_derived_from_it
      followers = User.from_id(1, client: @client).followers

      refute_predicate Cursor.new(User, "users/1/followers", client: @client), :app_only?
      assert_equal [false, false, false, false], [followers, followers.refresh, followers.prefetch, followers.stubs].map(&:app_only?)
    end

    def test_a_cursor_that_is_not_app_only_fetches_with_the_client_it_was_given
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}], "meta" => {"result_count" => 1}})

      assert_equal 2, User.from_id(1, client: @client).followers.first.id
      assert_equal ["users/1/followers"], @client.paths
      assert_empty @client.app.requests
    end

    def test_the_posts_of_a_space_use_the_app_only_client
      @client.app.stub(:get, "spaces/1DXxyRYNejbKM/tweets", {"data" => [{"id" => "1", "text" => "Hello"}], "meta" => {"result_count" => 1}})
      space = Space.from_id("1DXxyRYNejbKM", client: @client)

      posts = space.posts

      assert_equal ["Hello"], posts.map(&:text)
      assert_same @client, posts.client
      assert_same @client, posts.first.client
      assert_equal ["spaces/1DXxyRYNejbKM/tweets"], @client.app.paths
      assert_empty @client.requests
    end

    def test_hydrating_a_space_uses_the_app_only_client
      @client.app.stub(:get, "spaces/1DXxyRYNejbKM", {"data" => {"id" => "1DXxyRYNejbKM", "title" => "Ruby"}})

      assert_equal "Ruby", Space.from_id("1DXxyRYNejbKM", client: @client).hydrate.title
      assert_equal ["spaces/1DXxyRYNejbKM"], @client.app.paths
      assert_empty @client.requests
    end

    def test_a_client_without_an_app_only_client_is_used_as_it_is
      client = FakeClient.new.stub(:get, "spaces/1DXxyRYNejbKM", {"data" => {"id" => "1DXxyRYNejbKM", "title" => "Ruby"}})

      assert_equal "Ruby", client.find_space("1DXxyRYNejbKM").title
      assert_equal ["spaces/1DXxyRYNejbKM"], client.paths
    end

    def test_other_resources_keep_the_client_they_are_given
      @client.stub(:get, "users/7505382", {"data" => {"id" => "7505382", "username" => "sferik"}})

      assert_equal "sferik", @client.find_user(7_505_382).username
      assert_same @client, User.client_for(@client)
      assert_empty @client.app.requests
    end

    def test_the_posts_of_a_space_without_a_client_raise
      assert_raises(ArgumentError) { Space.from_id("1DXxyRYNejbKM").posts }
    end
  end
end
