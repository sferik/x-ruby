# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A trend and the usage of a project match a hash pattern as a resource does, by what their readers read
  class ValuePatternMatchingTest < Minitest::Test
    cover Trend
    cover PersonalizedTrend
    cover PostUsage
    cover Objects.const_get(:Utils)

    def setup
      @trend = Trend.new({"trend_name" => "#ruby", "tweet_count" => "1234"})
      @personalized = PersonalizedTrend.new({"trend_name" => "#ruby", "category" => "Technology", "post_count" => "12.3K posts"})
      @usage = PostUsage.new({"project_usage" => "1234", "project_cap" => "3000000", "daily_project_usage" => {"usage" => "many"}})
    end

    def test_a_trend_matches_a_hash_pattern_as_its_readers_read_it
      matched = case @trend
      in {name: "#ruby", post_count: 1000.. => count} then count
      end

      assert_equal 1234, matched
      assert_pattern { @trend => {tweet_count: 1234} }
    end

    def test_a_trend_gives_every_reader_by_its_own_name
      assert_equal({name: "#ruby", post_count: 1234}, @trend.deconstruct_keys(nil))
      assert_equal({tweet_count: 1234}, @trend.deconstruct_keys(%i[tweet_count trend_name]))
    end

    def test_a_personalized_trend_matches_a_hash_pattern
      assert_equal({name: "#ruby", category: "Technology", post_count_text: "12.3K posts", trending_since: nil}, @personalized.deconstruct_keys(nil))
      assert_equal({category: "Technology"}, @personalized.deconstruct_keys(%i[category post_count]))
      assert_pattern { @personalized => {category: "Technology", trending_since: nil} }
    end

    def test_the_usage_matches_a_hash_pattern_reading_only_what_it_names
      matched = case @usage
      in {project_usage: Integer => used, project_cap: Integer => cap} then cap - used
      end

      assert_equal 2_998_766, matched
      assert_equal({project_id: nil}, @usage.deconstruct_keys(%i[project_id]))
      assert_raises(InvalidAttribute) { @usage.deconstruct_keys(nil) }
    end

    def test_the_usage_gives_every_reader_to_a_pattern_that_asks_for_every_key
      usage = PostUsage.new({"project_id" => "1", "cap_reset_day" => 16})

      assert_equal({project_id: 1, project_usage: nil, project_cap: nil, cap_reset_day: 16, daily: {}, daily_by_app: {}}, usage.deconstruct_keys(nil))
    end
  end
end
