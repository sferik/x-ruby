# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    # hydrate_all looks up no resource that hydrate, or an earlier hydrate_all, already found, since the API bills
    # each resource a lookup returns
    class ResourceHydrateAllStoredTest < Minitest::Test
      cover Resource
      cover Resources.const_get(:Finders)
      cover Resources.const_get(:BatchFinders)

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id, "username" => "user#{id}"} }} })
      end

      def test_hydrate_all_looks_up_no_stub_an_earlier_hydrate_all_found
        stubs = [User.from_id(2), User.from_id(3)]
        User.hydrate_all(stubs, client: @client)

        assert_equal %w[user2 user3], User.hydrate_all(stubs, client: @client).map(&:username)
        assert_equal ["2,3"], @client.queries.map { |query| query["ids"] }
      end

      def test_hydrate_all_looks_up_no_stub_hydrate_found
        @client.stub(:get, "users/2", {"data" => {"id" => "2", "username" => "user2"}})
        found = User.new({"id" => "2"}, client: @client)
        found.hydrate

        assert_equal %w[user2 user3], User.hydrate_all([found, User.from_id(3)], client: @client).map(&:username)
        assert_equal %w[users/2 users], @client.paths
      end

      # A concurrency that would look nothing up is refused even when every resource is hydrated already
      def test_hydrate_all_refuses_a_concurrency_below_one_with_nothing_to_look_up
        hydrated = User.new({"id" => "1"}, client: @client, hydrated: true)

        assert_raises(ArgumentError) { User.hydrate_all([hydrated], client: @client, concurrency: 0) }
        assert_empty @client.requests
      end
    end
  end
end
