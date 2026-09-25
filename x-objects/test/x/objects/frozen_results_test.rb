# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The resources a lookup or a cursor returns come in a frozen Array, as every collection the object layer holds does
  class FrozenResultsTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover Objects::Finders
    cover Objects::UserFinders

    def setup
      @client = FakeClient.new
      lookup = ->(query, _) { data(query.fetch("ids") { query["usernames"].delete("user") }.split(",")) }
      %w[users users/by tweets].each { |path| @client.stub(:get, path, lookup) }
      @client.stub(:get, "users/1/followers", data(%w[2 3]))
    end

    def test_the_resources_a_batch_lookup_finds_are_frozen
      assert_all_frozen [Post.find_all([1, 2], client: @client), User.find_all([1, "user2"], client: @client),
        User.find_all_by_id([1], client: @client), User.find_all_by_username(["user2"], client: @client)]
    end

    def test_the_resources_hydrate_all_returns_are_frozen
      expanded = User.new({"id" => "1"}, client: @client, hydrated: true)

      assert_all_frozen [User.hydrate_all([expanded], client: @client), User.hydrate_all([User.from_id(2), nil], client: @client)]
    end

    def test_the_first_resources_of_a_cursor_and_their_identifiers_are_frozen
      followers = User.new({"id" => "1"}, client: @client).followers

      assert_all_frozen [followers.first(2), followers.take(1), followers.ids]
    end

    private

    def data(ids) = {"data" => ids.map { |id| {"id" => id, "username" => "user#{id}"} }}

    def assert_all_frozen(arrays)
      arrays.each { |array| assert_predicate array, :frozen?, "Expected #{array.inspect} to be frozen" }
    end
  end
end
