# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class SpaceCreatorsAndBuyersTest < Minitest::Test
    cover Space
    cover Objects.const_get(:Lookups)

    # A client with an app-only client, as an X::Client that signs with OAuth 1.0a has
    class UserClient < FakeClient
      attr_reader :app

      def initialize
        super
        @app = FakeClient.new
      end

      def app_only = app
    end

    def setup
      @client = UserClient.new
      @client.app.stub(:get, "spaces/by/creator_ids", lambda { |query, _|
        {"data" => query["user_ids"].split(",").map { |id| {"id" => "S#{id}", "creator_id" => id, "title" => "Space of #{id}"} },
         "errors" => [{"title" => "Not Found Error", "value" => "5"}]}
      })
    end

    def test_the_spaces_of_many_creators_ask_for_every_field_as_the_app
      spaces = @client.find_all_spaces_by_creator([1, "2", User.from_id(3)], state: "live")

      assert_equal [%w[S1 1], %w[S2 2], %w[S3 3]], spaces.map { |space| [space.id, space.creator.id.to_s] }
      assert_equal [{"user_ids" => "1,2,3", "state" => "live", **Objects.const_get(:Utils).query(Space.default_params)}], @client.app.queries
      assert_empty @client.requests
    end

    def test_the_spaces_of_many_creators_are_hydrated_and_frozen
      spaces = Space.find_all_by_creator([1], client: @client)

      assert(spaces.all?(&:hydrated?))
      assert_predicate spaces, :frozen?
    end

    def test_the_spaces_of_many_creators_are_looked_up_a_hundred_users_at_a_time
      spaces = Space.find_all_by_creator((1..150).to_a, client: @client, concurrency: 1)

      assert_equal 150, spaces.size
      assert_equal [100, 50], @client.app.queries.map { |query| query["user_ids"].split(",").size }
    end

    def test_the_spaces_of_many_creators_yield_the_problems
      yielded = []
      @client.find_all_spaces_by_creator([1], concurrency: 2) { |problem| yielded << problem.value }

      assert_equal ["5"], yielded
    end

    def test_a_creator_that_is_not_one_is_refused_before_a_request
      assert_raises(ArgumentError) { Space.find_all_by_creator(["sferik"], client: @client) }
      assert_raises(ArgumentError) { Space.find_all_by_creator([Post.from_id(1)], client: @client) }
      assert_raises(ArgumentError) { @client.find_all_spaces_by_creator([1], concurrency: 0) }
      assert_empty @client.app.requests
    end

    def test_the_buyers_of_a_space_are_read_as_the_user
      @client.stub(:get, "spaces/1DXxyRYNejbKM/buyers", {"data" => [{"id" => "7", "username" => "buyer"}]})
      buyers = Space.from_id("1DXxyRYNejbKM", client: @client).buyers

      assert_equal ["buyer"], buyers.map(&:username)
      assert_equal [{"max_results" => "100", **Objects.const_get(:Utils).query(User.default_params)}], @client.queries
      assert_empty @client.app.requests
      refute buyers.__send__(:app_only?)
    end

    def test_the_buyers_of_a_space_take_parameters
      @client.stub(:get, "spaces/1DXxyRYNejbKM/buyers", {"data" => []})
      Space.from_id("1DXxyRYNejbKM", client: @client).buyers(max_results: 10).to_a

      assert_equal "10", @client.queries.first["max_results"]
    end
  end
end
