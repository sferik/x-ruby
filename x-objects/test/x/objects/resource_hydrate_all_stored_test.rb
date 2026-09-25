# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    # hydrate_all looks up no resource that hydrate, or an earlier hydrate_all, already found, since the API bills
    # each resource a lookup returns
    class ResourceHydrateAllStoredTest < Minitest::Test
      cover Resource
      cover Objects::Finders

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
    end
  end
end
