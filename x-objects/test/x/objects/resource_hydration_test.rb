require_relative "../../test_helper"

module X
  module Objects
    class ResourceHydrationTest < Minitest::Test
      cover Resource
      cover Objects::Finders

      def setup
        @client = FakeClient.new
        @user = User.new({"id" => "1", "username" => "sferik"}, client: @client)
      end

      def test_hydrate_returns_self_when_hydrated
        user = User.new({"id" => "1"}, client: @client, hydrated: true)

        assert_same user, user.hydrate
        assert_empty @client.requests
      end

      def test_hydrate_fetches_and_memoizes
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "Erik Berlin"}})
        hydrated = @user.hydrate

        assert_equal "Erik Berlin", hydrated.name
        assert_predicate hydrated, :hydrated?
        assert_same hydrated, @user.hydrate
        assert_equal 1, @client.requests.size
      end

      def test_hydrate_an_id_that_could_be_a_username_uses_the_id_endpoint
        user = User.new({"id" => "12345"}, client: @client)
        @client.stub(:get, "users/12345", {"data" => {"id" => "12345"}})

        assert_equal 12_345, user.hydrate.id
        assert_equal ["users/12345"], @client.paths
      end

      def test_hydrate_requests_default_params
        @client.stub(:get, "users/1", {"data" => {"id" => "1"}})
        @user.hydrate

        assert_equal Utils.query(User.default_params), @client.queries.first
      end

      def test_hydrate_memoizes_missing_resource
        @client.stub(:get, "users/1", {"errors" => [{"title" => "Not Found Error"}]})

        assert_nil @user.hydrate
        assert_nil @user.hydrate
        assert_equal 1, @client.requests.size
      end

      def test_hydrate_without_client
        error = assert_raises(ArgumentError) { User.new({"id" => "1"}).hydrate }

        assert_equal "X::User has no client", error.message
      end

      def test_hydrate_without_endpoint
        error = assert_raises(NotImplementedError) { Media.new({"media_key" => "3_1"}, client: @client).hydrate }

        assert_equal "X::Media cannot be fetched by media_key", error.message
        assert_empty @client.requests
      end

      def test_hydrate_without_endpoint_or_client
        assert_raises(NotImplementedError) { Media.new({"media_key" => "3_1"}).hydrate }
      end

      def test_refresh_fetches_again_and_replaces_memo
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "Old"}})
        old = @user.hydrate
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "New"}})
        fresh = @user.refresh

        assert_equal "New", fresh.name
        refute_same old, fresh
        assert_same fresh, @user.hydrate
        assert_equal 2, @client.requests.size
      end

      def test_refresh_hydrated_resource_fetches
        user = User.new({"id" => "1", "name" => "Old"}, client: @client, hydrated: true)
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "New"}})

        assert_equal "New", user.refresh.name
        assert_equal "New", user.hydrate.name
      end

      def test_cursor_without_client
        error = assert_raises(ArgumentError) { User.new({"id" => "1"}).followers }

        assert_equal "X::User has no client", error.message
      end

      def test_cursor_merges_params
        cursor = @user.followers("user.fields": "id", max_results: 5)

        assert_equal "users/1/followers", cursor.path
        assert_equal 5, cursor.params["max_results"]
        assert_equal "id", cursor.params["user.fields"]
        assert_equal Post::FIELDS.join(","), cursor.params["post.fields"]
        assert_same @client, cursor.client
      end
    end
  end
end
