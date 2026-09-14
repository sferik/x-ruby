require_relative "../../test_helper"

module X
  module Objects
    class ResourceResponseTest < Minitest::Test
      cover Resource

      def setup
        @client = FakeClient.new
      end

      def test_from_response_with_nil_body
        assert_nil User.from_response(nil, client: @client)
      end

      def test_from_response_with_array_data_builds_each_resource
        users = User.from_response({"data" => [{"id" => "1"}, {"id" => "2"}]}, client: @client)

        assert_equal %w[1 2], users.map(&:id)
        assert_predicate users, :frozen?
        assert_same @client, users.first.client
      end

      def test_from_response_accepts_array_subclasses
        data = Class.new(Array).new([{"id" => "1"}])

        assert_equal ["1"], User.from_response({"data" => data}, client: @client).map(&:id)
      end

      def test_resource_from_response_with_array_data
        assert_nil User.resource_from_response({"data" => [{"id" => "1"}]}, client: @client)
      end

      def test_resource_from_response_is_not_hydrated_by_default
        refute_predicate User.resource_from_response({"data" => {"id" => "1"}}, client: @client), :hydrated?
      end

      def test_from_response_with_includes
        body = {"data" => {"id" => "1", "pinned_tweet_id" => "2"}, "includes" => {"tweets" => [{"id" => "2", "text" => "hi"}]}}
        user = User.from_response(body, client: @client)

        assert_equal "hi", user.pinned_post.text
        assert_same @client, user.client
      end

      def test_from_response_is_not_hydrated_by_default
        refute_predicate User.from_response({"data" => {"id" => "1"}}, client: @client), :hydrated?
        refute User.from_response({"data" => [{"id" => "1"}]}, client: @client).any?(&:hydrated?)
      end

      def test_from_response_hydrated
        assert_predicate User.from_response({"data" => {"id" => "1"}}, client: @client, hydrated: true), :hydrated?
        assert User.from_response({"data" => [{"id" => "1"}]}, client: @client, hydrated: true).all?(&:hydrated?)
      end

      def test_collection_from_response
        body = {"data" => [{"id" => "1", "author_id" => "9"}, {"id" => "2", "author_id" => "9"}]}
        posts = Post.collection_from_response(body, client: @client)

        assert_equal %w[1 2], posts.map(&:id)
        assert_predicate posts, :frozen?
        assert_same @client, posts.first.client
        refute(posts.any?(&:hydrated?))
      end

      def test_collection_from_response_hydrated
        body = {"data" => [{"id" => "1"}, {"id" => "2"}]}

        assert(Post.collection_from_response(body, client: @client, hydrated: true).all?(&:hydrated?))
      end

      def test_collection_from_response_shares_includes
        body = {"data" => [{"id" => "1", "author_id" => "9"}, {"id" => "2", "author_id" => "9"}],
                "includes" => {"users" => [{"id" => "9", "username" => "sferik"}]}}
        posts = Post.collection_from_response(body, client: @client)

        assert_same posts.first.author, posts.last.author
        assert_equal "sferik", posts.first.author.username
      end

      def test_collection_from_response_with_nil_body
        assert_empty User.collection_from_response(nil, client: @client)
      end

      def test_from_response_ignores_includes_without_data
        assert_nil User.from_response({"includes" => {"users" => []}}, client: @client)
      end

      def test_collection_from_response_with_hash_data
        assert_empty User.collection_from_response({"data" => {"id" => "1"}}, client: @client)
      end

      def test_resolve_through_identity_map
        includes = Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
        post = Post.new({"id" => "1", "author_id" => "9"}, client: @client, includes:)

        assert_equal "sferik", post.author.username
        assert_same @client, post.author.client
        assert_same includes.resolve(User, "9", client: @client), post.author
      end

      def test_resolve_stub_shares_includes_and_client
        includes = Includes.new({"users" => [{"id" => "8"}]})
        post = Post.new({"id" => "1", "author_id" => "9"}, client: @client, includes:)

        assert_same includes, post.author.includes
        assert_same @client, post.author.client
        refute_predicate post.author, :hydrated?
        assert_equal({"id" => "9"}, post.author.attrs)
      end

      def test_resolve_missing_reference
        assert_nil Post.new({"id" => "1"}, client: @client).author
      end

      def test_hydrating_a_shared_reference_hydrates_it_everywhere
        body = {"data" => [{"id" => "1", "author_id" => "9"}, {"id" => "2", "author_id" => "9"}]}
        @client.stub(:get, "users/9", {"data" => {"id" => "9", "name" => "Erik Berlin"}})
        first, second = Post.collection_from_response(body, client: @client)
        first.author.hydrate

        assert_equal "Erik Berlin", second.author.hydrate.name
        assert_equal 1, @client.requests.size
      end

      def test_from_response_accepts_hash_subclasses
        data = Class.new(Hash).new.merge!("id" => "1")

        assert_equal "1", User.from_response({"data" => data}, client: @client).id
      end

      def test_collection_from_response_accepts_array_subclasses
        data = Class.new(Array).new([{"id" => "1"}])

        assert_equal ["1"], User.collection_from_response({"data" => data}, client: @client).map(&:id)
      end
    end
  end
end
