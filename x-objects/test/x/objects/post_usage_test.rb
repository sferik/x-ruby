# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostUsageTest < Minitest::Test
    cover PostUsage
    cover Objects.const_get(:Lookups)

    DATA = {
      "project_id" => "1234567890", "project_usage" => "1234", "project_cap" => "3000000", "cap_reset_day" => 16,
      "daily_project_usage" => {"project_id" => "1234567890", "usage" => [{"date" => "2026-09-14T00:00:00.000Z", "usage" => "010"}, {"date" => "2026-09-15T00:00:00.000Z"}]},
      "daily_client_app_usage" => [{"client_app_id" => "42", "usage" => [{"date" => "2026-09-15T00:00:00.000Z", "usage" => "3"}], "usage_result_count" => 1},
        {"usage_result_count" => 0}]
    }.freeze

    def setup
      @client = FakeClient.new
      @client.stub(:get, "usage/tweets", {"data" => DATA})
    end

    def test_current_requests_every_field
      usage = PostUsage.current(client: @client, days: 30)

      refute_respond_to PostUsage, :find
      assert_equal DATA, usage.to_h
      assert_equal [{"usage.fields" => PostUsage::FIELDS.join(","), "days" => "30"}], @client.queries
    end

    def test_totals
      usage = @client.post_usage(days: 2)

      assert_equal [1_234_567_890, 1234, 3_000_000, 16], [usage.project_id, usage.project_usage, usage.project_cap, usage.cap_reset_day]
      assert_equal "2", @client.queries.first["days"]
      assert_predicate usage, :frozen?
      assert_predicate usage.attrs, :frozen?
    end

    def test_the_reset_day_is_read_as_an_integer_whether_it_is_a_number_or_a_string
      assert_equal [16, 16], [PostUsage.new({"cap_reset_day" => 16}).cap_reset_day, PostUsage.new({"cap_reset_day" => "16"}).cap_reset_day]
      assert_equal 'X::PostUsage#cap_reset_day cannot be read from "soon"', assert_raises(InvalidAttribute) { PostUsage.new({"cap_reset_day" => "soon"}).cap_reset_day }.message
    end

    def test_daily_usage_counts_a_day_without_a_number_as_zero
      daily = PostUsage.new(DATA).daily

      assert_equal({Time.utc(2026, 9, 14) => 10, Time.utc(2026, 9, 15) => 0}, daily)
      assert_predicate daily, :frozen?
    end

    def test_daily_usage_by_app
      by_app = PostUsage.new(DATA).daily_by_app

      assert_equal({42 => {Time.utc(2026, 9, 15) => 3}, nil => {}}, by_app)
      assert_predicate by_app, :frozen?
      assert_predicate by_app[42], :frozen?
    end

    def test_attributes_are_deep_frozen
      usage = PostUsage.new({"project_usage" => +"1", "daily_project_usage" => {"usage" => []}})

      assert_predicate usage.attrs, :frozen?
      assert_predicate usage.attrs["project_usage"], :frozen?
      assert_predicate usage.attrs.dig("daily_project_usage", "usage"), :frozen?
    end

    def test_an_empty_usage
      usage = PostUsage.new({})

      assert_equal [nil, nil, nil, nil, {}, {}], [usage.project_id, usage.project_usage, usage.project_cap, usage.cap_reset_day, usage.daily, usage.daily_by_app]
    end

    def test_a_response_whose_usage_is_empty_or_not_an_object
      assert_empty PostUsage.current(client: FakeClient.new.stub(:get, "usage/tweets", {"data" => {}})).to_h
      assert_nil PostUsage.current(client: FakeClient.new.stub(:get, "usage/tweets", {"data" => []}))
    end

    def test_a_response_without_usage_returns_nil_and_reports_its_problems
      @client.stub(:get, "usage/tweets", {"errors" => [{"title" => "Forbidden", "detail" => "Usage is not available."}]})
      titles = []

      assert_nil PostUsage.current(client: @client) { |problem| titles << problem.title }
      assert_nil @client.post_usage { |problem| titles << problem.detail }
      assert_nil PostUsage.current(client: @client)
      assert_nil PostUsage.current(client: FakeClient.new.stub(:get, "usage/tweets", nil))
      assert_equal ["Forbidden", "Usage is not available."], titles
    end

    def test_current_bang_returns_the_usage
      assert_equal DATA, PostUsage.current!(client: @client).to_h
      assert_equal DATA, @client.post_usage!(days: 2).to_h
      assert_equal [{"usage.fields" => PostUsage::FIELDS.join(","), "days" => "2"}], @client.queries.drop(1)
    end

    def test_current_bang_raises_with_the_problems_of_a_response_without_usage
      @client.stub(:get, "usage/tweets", {"errors" => [{"title" => "Forbidden", "detail" => "Usage is not available."}]})

      error = assert_raises(MissingResource) { @client.post_usage! }

      assert_equal "usage/tweets returned no usage: Usage is not available.", error.message
      assert_equal ["Forbidden"], error.problems.map(&:title)
    end
  end
end
