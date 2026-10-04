# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class StreamRuleTest < Minitest::Test
    cover StreamRule
    cover Streams.const_get(:Validator)

    def setup
      @rule = StreamRule.new(id: "1165037377523306498", value: "ruby -is:retweet", tag: "ruby")
    end

    def test_a_rule_reads_its_identifier_as_an_integer
      assert_equal [1_165_037_377_523_306_498, 10], [@rule.id, StreamRule.new(id: "010", value: "ruby").id]
      assert_equal 7, StreamRule.new(id: 7, value: "ruby").id
    end

    def test_a_rule_holds_its_value_and_tag
      assert_equal ["ruby -is:retweet", "ruby"], [@rule.value, @rule.tag]
    end

    def test_a_rule_built_to_be_added_has_neither_an_identifier_nor_a_tag_unless_given_them
      rule = StreamRule.new(value: "ruby")

      assert_equal({id: nil, value: "ruby", tag: nil}, rule.to_h)
    end

    def test_a_rule_is_frozen_and_keeps_copies_of_what_it_was_given
      value = +"ruby"
      tag = +"tag"
      rule = StreamRule.new(value:, tag:)
      value << " -is:retweet"

      assert_predicate rule, :frozen?
      assert_equal ["ruby", false, false], [rule.value, value.frozen?, tag.frozen?]
      assert_predicate rule.value, :frozen?
      assert_predicate rule.tag, :frozen?
    end

    def test_a_rule_is_a_hash_of_its_identifier_value_and_tag
      assert_equal({id: 1_165_037_377_523_306_498, value: "ruby -is:retweet", tag: "ruby"}, @rule.to_h)
    end

    def test_a_rule_matches_a_pattern_of_its_attributes
      matched = case @rule
      in {id: Integer => id, value: /ruby/, tag: nil} then [:untagged, id]
      in {id: Integer => id, value: /ruby/, tag: String => tag} then [tag, id]
      end

      assert_equal ["ruby", 1_165_037_377_523_306_498], matched
    end

    def test_rules_of_the_same_identifier_value_and_tag_are_equal
      same = StreamRule.new(id: 1_165_037_377_523_306_498, value: "ruby -is:retweet", tag: "ruby")

      assert_equal same, @rule
      assert @rule.eql?(same)
      assert_equal same.hash, @rule.hash
      assert_equal 1, [same, @rule].uniq.size
    end

    def test_rules_that_differ_are_not_equal
      refute_equal StreamRule.new(value: "ruby -is:retweet", tag: "ruby"), @rule
      refute_equal @rule.to_h, @rule
      refute_equal Class.new(StreamRule).new(**@rule.to_h), @rule
    end

    def test_rules_that_differ_hash_apart
      others = [StreamRule.new(value: "ruby"), @rule.to_h, [nil, @rule.to_h], Class.new(StreamRule).new(**@rule.to_h)]

      assert_equal others.size + 1, [@rule, *others].map(&:hash).uniq.size
    end

    def test_a_rule_summarizes_itself
      assert_equal '#<X::StreamRule id=1165037377523306498 value="ruby -is:retweet" tag="ruby">', @rule.inspect
      assert_equal '#<X::StreamRule id=nil value="ruby" tag=nil>', StreamRule.new(value: "ruby").inspect
    end

    def test_a_rule_refuses_a_value_or_a_tag_that_is_not_a_string
      assert_equal "value must be a String, not nil", assert_raises(ArgumentError) { StreamRule.new(value: nil) }.message
      assert_equal "tag must be a String, not :ruby", assert_raises(ArgumentError) { StreamRule.new(value: "ruby", tag: :ruby) }.message
    end

    def test_a_rule_refuses_an_identifier_that_names_no_number
      ["0x1", "one", 1.5].each { |id| assert_raises(ArgumentError) { StreamRule.new(id:, value: "ruby") } }
    end

    def test_a_rule_refuses_an_identifier_x_resources_refuses
      [" 1_0 ", "1_0", " 10", "10\n", "-1", "+1", "", -1, 1.0, :"1"].each do |id|
        error = assert_raises(ArgumentError) { StreamRule.new(id:, value: "ruby") }

        assert_equal "invalid value for Integer(): #{id.to_s.inspect}", error.message
      end
    end

    def test_a_rule_reads_an_identifier_of_digits_alone_or_an_integer_that_is_not_negative
      assert_equal [0, 0, 10], [StreamRule.new(id: 0, value: "ruby").id, StreamRule.new(id: "0", value: "ruby").id, StreamRule.new(id: "10", value: "ruby").id]
    end
  end
end
