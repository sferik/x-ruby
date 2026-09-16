require_relative "../../test_helper"

module X
  class CursorStubHydrationTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover Objects::Batch
    cover Objects::Resource
    cover User

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_hydrating_one_stub_looks_up_every_stub_of_its_page
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
