# frozen_string_literal: true

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

    def test_a_rule_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { StreamRule.allocate.marshal_load(["1", {value: "ruby"}]) }

      assert_equal 'X::StreamRule reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { StreamRule.allocate.marshal_load({value: "ruby"}) }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { StreamRule::MARSHAL_FORMAT }
    end
  end
end
