# frozen_string_literal: true

require "yaml"
require_relative "../../test_helper"

module X
  # Marshal writes a rule of the filtered stream as plain data, led by the number of its format, and reads it back frozen
  class StreamRuleMarshalTest < Minitest::Test
    cover StreamRule

    def setup
      @rules = [StreamRule.new(id: "1165037377523306498", value: "ruby -is:retweet", tag: "ruby"), StreamRule.new(value: "ruby")]
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [[1, {id: 1_165_037_377_523_306_498, value: "ruby -is:retweet", tag: "ruby"}], [1, {id: nil, value: "ruby", tag: nil}]], @rules.map(&:marshal_dump)
    end

    def test_a_marshalled_rule_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@rules))

      assert_equal @rules, loaded
      assert_equal [StreamRule, StreamRule], loaded.map(&:class)
    end

    def test_a_marshalled_rule_reads_back_frozen
      Marshal.load(Marshal.dump(@rules)).each do |rule|
        assert_predicate rule, :frozen?
        assert_predicate rule.value, :frozen?
      end
      assert_predicate Marshal.load(Marshal.dump(@rules.first)).tag, :frozen?
    end

    def test_a_rule_a_later_release_added_to_reads_back_as_it_was
      loaded = StreamRule.allocate.tap { |rule| rule.marshal_load([1, {id: 1, value: "ruby", tag: "ruby", added: true}, "added"]) }

      assert_equal StreamRule.new(id: 1, value: "ruby", tag: "ruby"), loaded
    end

    def test_a_rule_of_another_format_is_refused
      error = assert_raises(UnsupportedFormat) { StreamRule.allocate.marshal_load(["1", {value: "ruby"}]) }

      assert_equal 'X::StreamRule reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedFormat) { StreamRule.allocate.marshal_load({value: "ruby"}) }
    end

    def test_yaml_writes_the_format_and_each_part_under_its_name
      assert_equal({"format" => 1, "id" => 1_165_037_377_523_306_498, "value" => "ruby -is:retweet", "tag" => "ruby"},
        YAML.unsafe_load(YAML.dump(@rules.first).sub("!ruby/object:X::StreamRule", "")))
    end

    def test_a_rule_written_as_yaml_reads_back_frozen
      loaded = YAML.unsafe_load(YAML.dump(@rules))

      assert_equal @rules, loaded
      assert_equal [true] * 3, [loaded.first, loaded.first.value, loaded.first.tag].map(&:frozen?)
      assert_equal @rules.first, YAML.unsafe_load("#{YAML.dump(@rules.first)}added: true\n")
    end

    def test_a_rule_written_as_yaml_of_another_format_is_refused
      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load(YAML.dump(@rules.first).sub("format: 1", "format: 2")) }

      assert_equal "X::StreamRule reads format 1 of Marshal, not 2", error.message
      assert_raises(UnsupportedFormat) { YAML.unsafe_load("--- !ruby/object:X::StreamRule\nformat: 2\n") }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { StreamRule::MARSHAL_FORMAT }
    end
  end
end
