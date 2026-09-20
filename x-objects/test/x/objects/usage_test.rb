# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UsageTest < Minitest::Test
    cover Usage
    cover Objects::API::Lookups

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

    def test_find_requests_every_field
      usage = Usage.find(client: @client, days: 30)

      assert_equal DATA, usage.to_h
      assert_equal [{"usage.fields" => Usage::FIELDS.join(","), "days" => "30"}], @client.queries
    end

    def test_totals
      usage = @client.usage(days: 2)

      assert_equal [1_234_567_890, 1234, 3_000_000, 16], [usage.project_id, usage.project_usage, usage.project_cap, usage.cap_reset_day]
      assert_equal "2", @client.queries.first["days"]
      assert_predicate usage, :frozen?
      assert_predicate usage.attrs, :frozen?
    end

    def test_daily_usage_counts_a_day_without_a_number_as_zero
      daily = Usage.new(DATA).daily

      assert_equal({Time.utc(2026, 9, 14) => 10, Time.utc(2026, 9, 15) => 0}, daily)
      assert_predicate daily, :frozen?
    end

    def test_daily_usage_by_app
      by_app = Usage.new(DATA).daily_by_app

      assert_equal({42 => {Time.utc(2026, 9, 15) => 3}, nil => {}}, by_app)
      assert_predicate by_app, :frozen?
      assert_predicate by_app[42], :frozen?
    end

    def test_attributes_are_deep_frozen
      usage = Usage.new({"project_usage" => +"1", "daily_project_usage" => {"usage" => []}})

      assert_predicate usage.attrs, :frozen?
      assert_predicate usage.attrs["project_usage"], :frozen?
      assert_predicate usage.attrs.dig("daily_project_usage", "usage"), :frozen?
    end

    def test_an_empty_usage
      usage = Usage.new({})

      assert_equal [nil, nil, nil, nil, {}, {}], [usage.project_id, usage.project_usage, usage.project_cap, usage.cap_reset_day, usage.daily, usage.daily_by_app]
      assert_empty Usage.find(client: FakeClient.new.stub(:get, "usage/tweets", nil)).to_h
    end
  end
end
