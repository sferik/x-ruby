require_relative "../../test_helper"

module X
  module Objects
    class PartialErrorsTest < Minitest::Test
      cover Finders
      cover Resource
      cover Includes
      cover Cursor
      cover API::Lookups
      cover X::User
      cover X::Objects::UserFinders
      cover X::Page

      PINNED_MISSING = {"title" => "Not Found Error", "detail" => "Could not find tweet with pinned_tweet_id: [9].", "type" => "https://api.twitter.com/2/problems/resource-not-found", "parameter" => "pinned_tweet_id"}.freeze
      USER_MISSING = {"title" => "Not Found Error", "detail" => "Could not find user with ids: [5].", "resource_id" => "5", "parameter" => "ids"}.freeze

      def setup
        @client = FakeClient.new
      end

      def batch_sizes = @client.queries.map { |query| query["ids"].split(",").size }.sort.reverse

      def test_a_resource_reports_the_problems_of_its_response
        @client.stub(:get, "users/me", {"data" => {"id" => "1", "pinned_post_id" => "9"}, "errors" => [PINNED_MISSING]})
        user = @client.current_user

        assert_equal [PINNED_MISSING], user.problems.map(&:to_h)
        assert_same user.problems, user.pinned_post.problems
        assert_predicate user.problems, :frozen?
      end

      def test_a_resource_without_problems
        assert_empty User.new({"id" => "1"}).problems
        assert_predicate User.new({"id" => "1"}).problems, :frozen?
        assert_empty User.resource_from_response({"data" => {"id" => "1"}}, client: @client).problems
      end

      def test_every_resource_of_a_collection_shares_the_problems
        users = User.collection_from_response({"data" => [{"id" => "1"}, {"id" => "2"}], "errors" => [USER_MISSING]}, client: @client)

        assert_equal [["Could not find user with ids: [5]."]] * 2, users.map { |user| user.problems.map(&:detail) }
      end

      def test_find_yields_the_problems_and_find_bang_explains_itself
        @client.stub(:get, "users/5", {"errors" => [USER_MISSING]})
        yielded = []

        assert_nil User.find(5, client: @client) { |problem| yielded << problem.detail }
        assert_equal ["Could not find user with ids: [5]."], yielded
        error = assert_raises(ResourceNotFound) { @client.find_user!(5) }
        assert_equal "Could not find X::User 5: Could not find user with ids: [5].", error.message
        assert_equal [USER_MISSING], error.problems.map(&:to_h)
      end

      def test_find_by_username_yields_the_problems
        @client.stub(:get, "users/by/username/nobody", {"errors" => [{"title" => "Not Found Error"}]})
        yielded = []
        @client.find_user("nobody") { |problem| yielded << problem.title }

        assert_equal ["Not Found Error"], yielded
      end

      def test_find_all_yields_the_problems_of_every_batch
        @client.stub(:get, "tweets", ->(query, _) { {"data" => [], "errors" => (query["ids"].split(",").include?("5") ? [USER_MISSING] : [])} })
        yielded = []
        X::Post.find_all([5, *(6..105)], client: @client) { |problem| yielded << problem.resource_id }

        assert_equal ["5"], yielded
      end

      def test_find_all_asks_for_each_identifier_once
        @client.stub(:get, "tweets", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id} }} })
        posts = X::Post.find_all([1, "1", X::Post.from_id(1), *(6..105)], client: @client)

        assert_equal [1, *(6..105)], posts.map(&:id)
        assert_equal [100, 1], batch_sizes
      end

      def test_find_all_by_username_asks_for_each_username_once
        @client.stub(:get, "users/by", {"data" => [{"id" => "1", "username" => "sferik"}], "errors" => [{"title" => "Not Found Error", "value" => "nobody"}]})
        yielded = []
        users = User.find_all_by_username(["sferik", "@Sferik", "SFERIK", "nobody"], client: @client) { |problem| yielded << problem.to_h["value"] }

        assert_equal [1], users.map(&:id)
        assert_equal "sferik,nobody", @client.queries.first["usernames"]
        assert_equal ["nobody"], yielded
      end

      def test_find_all_without_a_block_ignores_the_problems
        @client.stub(:get, "tweets", {"errors" => [USER_MISSING]})

        assert_empty @client.find_posts([5])
      end

      def test_hydrate_all_and_lookups_pass_the_block_along
        @client.stub(:get, "users", {"data" => [{"id" => "1", "username" => "sferik"}], "errors" => [USER_MISSING]})
        @client.stub(:get, "users/me", {"data" => {"id" => "1"}, "errors" => [PINNED_MISSING]})
        yielded = []

        assert_equal ["sferik"], User.hydrate_all([User.from_id(1), User.from_id(5)], client: @client) { |problem| yielded << problem.parameter }.map(&:username)
        User.lookup("users/me", client: @client) { |problem| yielded << problem.parameter }
        User.lookup_all("users", client: @client) { |problem| yielded << problem.parameter }

        assert_equal %w[ids pinned_tweet_id ids], yielded
      end

      def test_lookup_all_builds_hydrated_resources_with_the_parameters
        @client.stub(:get, "users/by", {"data" => [{"id" => "1", "username" => "sferik"}]})
        users = User.lookup_all("users/by", client: @client, usernames: "sferik")

        assert_equal [[1, true]], users.map { |user| [user.id, user.hydrated?] }
        assert_same @client, users.first.client
        assert_equal "sferik", @client.queries.first["usernames"]
      end

      def test_current_user_missing_explains_itself
        @client.stub(:get, "users/me", {"errors" => [{"title" => "Unauthorized", "detail" => "The token was revoked."}]})
        error = assert_raises(ResourceNotFound) { @client.current_user }

        assert_equal "users/me returned no user: The token was revoked.", error.message
      end

      def test_pages_report_their_problems
        @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}], "errors" => [USER_MISSING]})
        page = User.from_id(1, client: @client).followers.page(0)

        assert_equal ["ids"], page.problems.map(&:parameter)
        assert_empty X::Page.new([], {}).problems
        assert_predicate page.problems, :frozen?
      end
    end
  end
end
