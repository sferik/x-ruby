# frozen_string_literal: true

require "yaml"
require_relative "../../test_helper"

module X
  # Marshal writes a trend, the usage of a project, and a rule a post matched as plain data, led by the number of their
  # format, and reads each back deep-frozen, as it was built
  class ValueMarshalTest < Minitest::Test
    cover Objects.const_get(:ValueMarshalling)
    cover Trend
    cover PersonalizedTrend
    cover PostUsage
    cover MatchingRule

    def setup
      @values = [Trend.new({"trend_name" => "#ruby", "tweet_count" => 1234}),
        PersonalizedTrend.new({"trend_name" => "#ruby", "category" => "Technology", "post_count" => "12.3K posts"}),
        PostUsage.new({"project_usage" => "1234", "daily_project_usage" => {"usage" => [{"date" => "2026-09-28T00:00:00.000Z", "usage" => "5"}]}}),
        MatchingRule.new({"id" => "1165037377523306498", "tag" => "ruby"}), MatchingRule.new({"id" => "1"})]
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal(@values.map { |value| [1, value.attrs] }, @values.map(&:marshal_dump))
    end

    def test_a_marshalled_value_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@values))

      assert_equal @values, loaded
      assert_equal @values.map(&:attrs), loaded.map(&:attrs)
      assert_equal [1_165_037_377_523_306_498, "ruby", 1, nil], loaded.last(2).flat_map { |rule| [rule.id, rule.tag] }
    end

    def test_a_marshalled_value_reads_back_deep_frozen
      Marshal.load(Marshal.dump(@values)).each do |value|
        assert_predicate value, :frozen?
        assert_predicate value.attrs, :frozen?
        assert value.attrs.values.all?(&:frozen?), "Expected the attributes of #{value.inspect} to be frozen"
      end
    end

    def test_a_value_a_later_release_added_to_reads_back_as_it_was
      @values.each do |value|
        assert_equal value, value.class.allocate.tap { |loaded| loaded.marshal_load([1, value.attrs, "added"]) }
      end
    end

    def test_a_value_of_another_format_is_refused
      @values.each do |value|
        error = assert_raises(UnsupportedMarshalFormat) { value.class.allocate.marshal_load(["1", value.attrs]) }

        assert_equal "#{value.class} reads format 1 of Marshal, not \"1\"", error.message
      end
    end

    def test_yaml_writes_the_state_marshal_writes_under_its_names
      @values.each do |value|
        assert_equal({"format" => 1, "attrs" => value.attrs}, YAML.unsafe_load(YAML.dump(value).sub("!ruby/object:#{value.class}", "")))
      end
    end

    def test_a_value_written_as_yaml_reads_back_deep_frozen
      @values.each do |value|
        loaded = YAML.unsafe_load(YAML.dump(value))

        assert_equal [value, value.attrs], [loaded, loaded.attrs]
        assert_equal [true, true], [loaded.frozen?, loaded.attrs.frozen?]
        assert_equal value, YAML.unsafe_load("#{YAML.dump(value)}added: true\n")
      end
    end

    def test_a_value_written_as_yaml_of_another_format_is_refused
      @values.each do |value|
        error = assert_raises(UnsupportedMarshalFormat) { YAML.unsafe_load(YAML.dump(value).sub("format: 1", "format: 2")) }

        assert_equal "#{value.class} reads format 1 of Marshal, not 2", error.message
        assert_raises(UnsupportedMarshalFormat) { YAML.unsafe_load("--- !ruby/object:#{value.class}\nformat: 2\n") }
      end
    end

    def test_the_format_is_named_privately
      [Trend, PersonalizedTrend, PostUsage, MatchingRule].each { |klass| assert_raises(NameError) { klass::MARSHAL_FORMAT } }
    end
  end
end
