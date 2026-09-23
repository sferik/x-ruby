# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A String of digits is an identifier to the finders that say so, as it is read from a response or an environment
  # variable, where find takes it for a username
  class UserFindByIdTest < Minitest::Test
    cover X::Objects::UserFinders
    cover X::Objects::API::Lookups

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/7505382", {"data" => {"id" => "7505382", "username" => "sferik"}})
      @client.stub(:get, "users/1", {"errors" => [{"title" => "Not Found Error", "detail" => "Could not find user with id: [1]."}]})
      @client.stub(:get, "users", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id} }} })
    end

    def test_a_string_of_digits_is_looked_up_by_identifier
      assert_equal "sferik", User.find_by_id("7505382", client: @client).username
      assert_equal "sferik", @client.find_user_by_id("7505382").username
      assert_equal "sferik", User.find_by_id(User.from_id(7_505_382), client: @client).username
      assert_equal ["users/7505382"] * 3, @client.paths
    end

    def test_a_lookup_by_identifier_takes_params_and_reports_problems
      problems = []

      assert_nil User.find_by_id(1, client: @client, "user.fields": "id") { |problem| problems << problem }
      assert_equal ["id", ["Could not find user with id: [1]."]], [@client.queries.first["user.fields"], problems.map(&:detail)]
    end

    def test_the_client_passes_params_and_reports_problems_of_a_lookup_by_identifier
      problems = []

      assert_nil @client.find_user_by_id("1", "user.fields": "id") { |problem| problems << problem.detail }
      assert_equal ["id", ["Could not find user with id: [1]."]], [@client.queries.first["user.fields"], problems]
    end

    def test_a_user_that_must_exist_is_looked_up_by_identifier
      assert_equal "sferik", User.find_by_id!("7505382", client: @client, "user.fields": "id,username").username
      assert_equal "sferik", @client.find_user_by_id!("7505382", "user.fields": "id,username").username
      assert_equal %w[id,username id,username], @client.queries.map { |query| query["user.fields"] }
    end

    def test_a_user_that_is_not_there_raises_naming_its_identifier
      [1, User.from_id(1)].each do |id|
        error = assert_raises(MissingResource) { @client.find_user_by_id!(id) }

        assert_equal "Could not find X::User 1: Could not find user with id: [1].", error.message
      end
    end

    def test_strings_of_digits_are_looked_up_by_identifier_in_batches
      assert_equal [7, 8], User.find_all_by_id(%w[7 8], client: @client, "user.fields": "id").map(&:id)
      assert_equal [7], @client.find_all_users_by_id([User.from_id(7)], concurrency: 1).map(&:id)
      assert_equal [["7,8", "id"], ["7", User::FIELDS.join(",")]], @client.queries.map { |query| [query["ids"], query["user.fields"]] }
    end

    def test_users_are_looked_up_by_identifier_four_batches_at_a_time_unless_told_otherwise
      given = concurrencies_of do
        @client.find_all_users_by_id(["7"])
        User.find_all_by_id(["7"], client: @client)
        @client.find_all_users_by_id(["7"], concurrency: 2)
      end

      assert_equal [4, 4, 2], given
    end

    def test_the_client_passes_params_and_reports_problems_of_a_lookup_by_identifier_in_batches
      @client.stub(:get, "users", {"data" => [{"id" => "7"}], "errors" => [{"detail" => "Could not find user with ids: [8]."}]})
      problems = []
      users = @client.find_all_users_by_id(%w[7 8], "user.fields": "id") { |problem| problems << problem.detail }

      assert_equal [[7], ["Could not find user with ids: [8]."], "id"], [users.map(&:id), problems, @client.queries.first["user.fields"]]
    end

    def test_a_value_that_is_not_an_identifier_is_refused
      assert_raises(ArgumentError) { User.find_by_id("sferik", client: @client) }
      assert_raises(ArgumentError) { @client.find_all_users_by_id(["sferik"]) }
      assert_empty @client.requests
    end

    private

    # The concurrency of each batch lookup the block made, in the order they were made
    def concurrencies_of
      given = []
      original = Objects::Parallel.method(:map)
      Objects::Parallel.stub(:map, ->(items, concurrency:, &block) { (given << concurrency) && original.call(items, concurrency:, &block) }) { yield }
      given
    end
  end
end
