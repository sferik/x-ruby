require_relative "../../test_helper"

module X
  class SpaceAppClientTest < Minitest::Test
    cover Space
    cover Objects::Finders
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

    def test_the_posts_of_a_space_use_the_app_only_client
      @client.app.stub(:get, "spaces/1DXxyRYNejbKM/tweets", {"data" => [{"id" => "1", "text" => "Hello"}], "meta" => {"result_count" => 1}})
      space = Space.from_id("1DXxyRYNejbKM", client: @client)

      assert_equal ["Hello"], space.posts.map(&:text)
      assert_same @client.app, space.posts.client
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
