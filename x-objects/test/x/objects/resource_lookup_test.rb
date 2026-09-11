require_relative "../../test_helper"

module X
  module Objects
    class ResourceLookupTest < Minitest::Test
      cover Resource

      def setup
        @client = FakeClient.new
      end

      def test_find
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "Erik Berlin"}})
        user = User.find(1, client: @client)

        assert_equal "Erik Berlin", user.name
        assert_predicate user, :hydrated?
        assert_same @client, user.client
        assert_equal ["users/1"], @client.paths
      end

      def test_find_by_resource
        @client.stub(:get, "tweets/2", {"data" => {"id" => "2"}})

        assert_equal "2", Post.find(Post.new({"id" => "2"}), client: @client).id
      end

      def test_find_merges_params_over_defaults
        @client.stub(:get, "users/1", {"data" => {"id" => "1"}})
        User.find(1, client: @client, "user.fields": "id", max_results: 5)
        query = @client.queries.first

        assert_equal "id", query["user.fields"]
        assert_equal "5", query["max_results"]
        assert_equal Post::FIELDS.join(","), query["tweet.fields"]
      end

      def test_find_drops_nil_params
        @client.stub(:get, "users/1", {"data" => {"id" => "1"}})
        User.find(1, client: @client, expansions: nil)

        refute @client.queries.first.key?("expansions")
      end

      def test_find_not_found
        @client.stub(:get, "users/1", {"errors" => []})

        assert_nil User.find(1, client: @client)
      end

      def test_find_all_batches_in_parallel
        ids = (1..150).map(&:to_s)
        @client.stub(:get, "tweets", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id} }} })
        posts = Post.find_all(ids, client: @client)

        assert_equal ids, posts.map(&:id)
        assert_equal [ids.first(100), ids.last(50)], batches
      end

      def test_find_all_builds_hydrated_resources_with_client
        @client.stub(:get, "tweets", {"data" => [{"id" => "1"}]})
        post = Post.find_all(["1"], client: @client).first

        assert_predicate post, :hydrated?
        assert_same @client, post.client
      end

      def test_find_all_uses_threads
        threads = Queue.new
        @client.stub(:get, "tweets", ->(_, _) { threads << Thread.current && {"data" => []} })
        Post.find_all((1..101).to_a, client: @client)

        assert_equal 2, threads.size
        refute_same Thread.current, threads.pop
      end

      def test_find_all_accepts_resources_and_integers
        @client.stub(:get, "users", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id} }} })

        assert_equal %w[1 2], User.find_all([User.new({"id" => "1"}), 2], client: @client).map(&:id)
      end

      def test_find_all_merges_params
        @client.stub(:get, "users", {"data" => []})
        User.find_all([1], client: @client, "user.fields": "id")

        assert_equal "id", @client.queries.first["user.fields"]
        assert_equal "1", @client.queries.first["ids"]
        assert_equal Post::FIELDS.join(","), @client.queries.first["tweet.fields"]
      end

      def test_find_all_with_no_ids
        assert_empty User.find_all([], client: @client)
        assert_empty @client.requests
      end

      def test_lookup_all_without_data
        @client.stub(:get, "users/by", {"meta" => {}})
        users = User.lookup_all("users/by", client: @client)

        assert_empty users
        assert_predicate users, :frozen?
      end

      private

      def batches
        @client.queries.map { |query| query["ids"].split(",") }.sort_by { |batch| -batch.size }
      end
    end
  end
end
