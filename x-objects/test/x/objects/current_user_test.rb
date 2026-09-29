# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CurrentUserTest < Minitest::Test
    cover Objects::API::Lookups

    def setup
      @client = FakeClient.new
    end

    def test_current_user_bang_looks_the_user_up_each_time
      @client.stub(:get, "users/me", {"data" => {"id" => "9", "public_metrics" => {"followers_count" => 1}}})
      first = @client.current_user!
      @client.stub(:get, "users/me", {"data" => {"id" => "9", "public_metrics" => {"followers_count" => 2}}})

      assert_equal [1, 2], [first.followers_count, @client.current_user!.followers_count]
      assert_equal ["users/me", "users/me"], @client.paths
    end

    def test_current_user_looks_the_user_up
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})

      assert_equal User.from_id(9), @client.current_user
    end

    def test_current_user_returns_nil_and_yields_the_problems_when_the_api_returns_no_user
      @client.stub(:get, "users/me", {"errors" => [{"title" => "Not Found Error", "detail" => "gone"}]})
      problems = []

      assert_nil @client.current_user { |problem| problems << problem.detail }
      assert_equal ["gone"], problems
    end

    def test_current_user_takes_query_parameters
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @client.current_user(**{"user.fields" => "id"})
      @client.current_user!(**{"user.fields" => "name"})

      assert_equal [{"user.fields" => "id"}, {"user.fields" => "name"}], @client.queries.map { |query| query.slice("user.fields") }
    end
  end
end
