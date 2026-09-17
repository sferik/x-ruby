require_relative "../../test_helper"

module X
  class CursorStubHydrationTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover Objects::Batch
    cover Objects::Resource
    cover User
    cover List
    cover Community
    cover DirectMessage

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_hydrating_one_stub_of_a_large_page_looks_up_no_more_than_one_batch
      stub_followers_and_lookup((1..250).map(&:to_s))
      stubs = @user.followers.stubs.to_a.values_at(149, 100)

      assert_equal ["Name 150", "Name 101"], stubs.map { |stub| stub.hydrate.name }
      assert_equal ["users/1/followers", "users"], @client.paths
      assert_equal [nil, [*101..200].join(",")], lookup_ids
    end

    def test_hydrating_every_stub_of_a_large_page_looks_up_each_batch_once
      stub_followers_and_lookup((1..250).map(&:to_s))

      assert_equal (1..250).map { |id| "Name #{id}" }, @user.followers.stubs.map { |stub| stub.hydrate.name }
      assert_equal [100, 100, 50], lookup_ids.drop(1).map { |ids| ids.split(",").size }
    end

    def lookup_ids = @client.queries.map { |query| query["ids"] }

    def stub_followers_and_lookup(ids)
      @client.stub(:get, "users/1/followers", {"data" => ids.map { |id| {"id" => id} }})
      @client.stub(:get, "users", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id, "name" => "Name #{id}"} }} })
    end

    def test_hydrating_one_stub_looks_up_every_stub_of_its_batch
      @client.stub(:get, "users", {"data" => [{"id" => "2", "name" => "Two"}, {"id" => "3", "name" => "Three"}]})
      stubs = @user.followers.stubs.to_a

      assert_equal %w[Two Three], stubs.map { |stub| stub.hydrate.name }
      assert_equal ["users/1/followers", "users"], @client.paths
      assert_equal "2,3", @client.queries.last["ids"]
    end

    def test_a_stub_the_lookup_does_not_find_hydrates_to_nothing
      @client.stub(:get, "users", {"data" => [{"id" => "2", "name" => "Two"}]})
      stubs = @user.followers.stubs.to_a

      assert_equal "Two", stubs.first.hydrate.name
      assert_nil stubs.last.hydrate
    end

    def test_the_stubs_of_a_resource_without_a_batch_lookup_hydrate_one_at_a_time
      @client.stub(:get, "users/1/owned_lists", {"data" => [{"id" => "2"}, {"id" => "3"}]})
      @client.stub(:get, "lists/2", {"data" => {"id" => "2", "name" => "Two"}})
      @client.stub(:get, "lists/3", {"data" => {"id" => "3", "name" => "Three"}})

      assert_equal %w[Two Three], @user.owned_lists.stubs.map { |stub| stub.hydrate.name }
      assert_equal ["users/1/owned_lists", "lists/2", "lists/3"], @client.paths
    end

    def test_only_resources_with_a_batch_lookup_are_batchable
      assert_equal [true, true, true, true], [User, Post, Space, Media].map(&:batchable?)
      assert_equal [false, false, false, false], [List, Community, DirectMessage, Poll].map(&:batchable?)
    end

    def test_refreshing_a_stub_of_a_page_looks_it_up_again_on_its_own
      @client.stub(:get, "users", {"data" => [{"id" => "2", "name" => "Two"}, {"id" => "3", "name" => "Three"}]})
      stub = @user.followers.stubs.first
      stub.hydrate
      @client.stub(:get, "users/2", {"data" => {"id" => "2", "name" => "Deux"}})

      assert_equal %w[Deux Deux], [stub.refresh.name, stub.hydrate.name]
      assert_equal ["users/1/followers", "users", "users/2"], @client.paths
    end

    def test_a_batch_is_frozen
      assert_predicate Objects::Batch.new(User, [], client: @client), :frozen?
    end

    def test_a_stub_of_its_own_is_looked_up_on_its_own
      @client.stub(:get, "users/2", {"data" => {"id" => "2", "name" => "Two"}})

      assert_equal "Two", User.from_id("2", client: @client).hydrate.name
      assert_equal ["users/2"], @client.paths
    end
  end
end
