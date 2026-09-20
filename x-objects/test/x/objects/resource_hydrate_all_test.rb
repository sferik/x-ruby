# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class ResourceHydrateAllTest < Minitest::Test
      cover Resource
      cover Objects::Finders

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id, "username" => "user#{id}"} }} })
        @expanded = User.new({"id" => "1", "username" => "expanded"}, client: @client, hydrated: true)
      end

      def test_hydrate_all_replaces_stubs_and_keeps_the_rest
        users = User.hydrate_all([@expanded, User.from_id(2), User.from_id(3)], client: @client)

        assert_equal %w[expanded user2 user3], users.map(&:username)
        assert_same @expanded, users.first
        assert_equal ["2,3"], @client.queries.map { |query| query["ids"] }
      end

      def test_hydrate_all_looks_up_each_stub_once
        users = User.hydrate_all([User.from_id(2), User.from_id(2), User.from_id(2)], client: @client)

        assert_equal %w[user2 user2 user2], users.map(&:username)
        assert_equal ["2"], @client.queries.map { |query| query["ids"] }
      end

      def test_hydrate_all_drops_stubs_that_are_not_found
        @client.stub(:get, "users", {"data" => [{"id" => "3", "username" => "user3"}]})

        assert_equal %w[user3], User.hydrate_all([User.from_id(2), User.from_id(3)], client: @client).map(&:username)
      end

      def test_hydrate_all_without_stubs
        assert_equal [@expanded], User.hydrate_all([@expanded], client: @client)
        assert_empty @client.requests
        assert_empty User.hydrate_all([], client: @client)
      end

      def test_hydrate_all_without_stubs_needs_no_batch_lookup
        lists = [List.new({"id" => "1", "name" => "Rubyists"}, client: @client, hydrated: true)]

        assert_equal lists, List.hydrate_all(lists, client: @client)
        assert_empty Media.hydrate_all([], client: @client)
        refute_same lists, List.hydrate_all(lists, client: @client)
      end

      def test_hydrate_all_merges_params
        User.hydrate_all([User.from_id(2)], client: @client, "user.fields": "id")

        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_hydrate_all_builds_hydrated_resources_with_client
        user = User.hydrate_all([User.from_id(2)], client: @client).first

        assert_predicate user, :hydrated?
        assert_same @client, user.client
      end

      def test_hydrate_all_looks_up_a_resource_that_is_not_a_stub_but_is_not_hydrated
        included = User.new({"id" => "2", "username" => "included"}, client: @client)
        users = User.hydrate_all([included], client: @client)

        assert_equal %w[user2], users.map(&:username)
        assert_predicate users.first, :hydrated?
        assert(User.hydrate_all([included, User.from_id(3)], client: @client).all?(&:hydrated?))
      end

      def test_hydrate_all_stores_what_it_found_in_the_originals
        stub = User.from_id(2, client: @client)
        included = User.new({"id" => "3", "username" => "included"}, client: @client)
        User.hydrate_all([stub, included], client: @client)
        requests = @client.requests.size

        assert_equal %w[user2 user3], [stub.hydrate.username, included.hydrate.username]
        assert_equal requests, @client.requests.size
      end

      def test_hydrate_all_stores_that_a_resource_was_not_found
        @client.stub(:get, "users", {"data" => []})
        stub = User.from_id(2, client: @client)

        assert_empty User.hydrate_all([stub], client: @client)
        assert_nil stub.hydrate
        assert_equal 1, @client.requests.size
      end

      def test_hydrate_all_batches_in_parallel
        stubs = (1..150).map { |id| User.from_id(id) }

        assert_equal 150, User.hydrate_all(stubs, client: @client).size
        assert_equal 2, @client.requests.size
      end
    end
  end
end
