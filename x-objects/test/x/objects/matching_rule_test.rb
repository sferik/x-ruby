# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A rule a post of the filtered stream matched holds what the stream sent of it, and reads its identifier and tag
  class MatchingRuleTest < Minitest::Test
    cover MatchingRule
    cover Objects.const_get(:ValueEquality)

    def test_a_rule
      rule = MatchingRule.new({"id" => "1165037377523306498", "tag" => "ruby"})

      assert_equal [1_165_037_377_523_306_498, "ruby"], [rule.id, rule.tag]
      assert_equal({id: 1_165_037_377_523_306_498, tag: "ruby"}, rule.deconstruct_keys(nil))
      assert_equal({tag: "ruby"}, rule.deconstruct_keys([:tag]))
      assert_equal '#<X::MatchingRule id=1165037377523306498 tag="ruby">', rule.inspect
    end

    def test_a_rule_without_a_tag_or_with_an_identifier_given_as_a_number
      assert_nil MatchingRule.new({"id" => "1"}).tag
      assert_equal 1, MatchingRule.new({"id" => 1}).id
      assert_equal "ruby", MatchingRule.new({"id" => "1", "tag" => Class.new(String).new("ruby")}).tag
    end

    def test_a_rule_names_its_attributes_by_strings
      assert_equal({"id" => "1", "tag" => "ruby"}, MatchingRule.new({id: "1", tag: "ruby"}).attrs)
    end

    def test_a_rule_is_serialized_by_its_attributes
      rule = MatchingRule.new({"id" => "1", "tag" => "ruby"})

      assert_same rule.attrs, rule.as_json
      assert_equal "[{\"id\":\"1\",\"tag\":\"ruby\"}]", [rule].to_json
      assert_equal "{\"id\":\"2\"}", MatchingRule.new({"id" => "2"}).to_json
    end

    def test_a_rule_is_frozen_and_keeps_a_copy_of_its_attributes
      attrs = {"id" => "1", "tag" => +"ruby"}
      rule = MatchingRule.new(attrs)
      attrs["tag"] << "!"
      attrs["id"] = "2"

      assert_equal [1, "ruby"], [rule.id, rule.tag]
      assert_predicate rule, :frozen?
      assert_predicate rule.tag, :frozen?
    end

    def test_a_rule_matches_a_pattern
      matched = [MatchingRule.new({"id" => "1", "tag" => "ruby"}), MatchingRule.new({"id" => "2"})].map do |rule|
        case rule
        in {id: 1, tag: "ruby"} then :ruby
        in {tag: nil} then :untagged
        end
      end

      assert_equal %i[ruby untagged], matched
    end

    def test_rules_of_the_same_attributes_are_equal
      rule = MatchingRule.new({"id" => "1", "tag" => "ruby"})

      assert_equal MatchingRule.new({"id" => "1", "tag" => "ruby"}), rule
      assert rule.eql?(MatchingRule.new({"id" => "1", "tag" => "ruby"}))
      assert_equal 1, [rule, MatchingRule.new({"id" => "1", "tag" => "ruby"})].uniq.size
    end

    def test_rules_of_other_attributes_or_another_class_are_not_equal
      rule = MatchingRule.new({"id" => "1", "tag" => "ruby"})

      assert_equal [false] * 4, [MatchingRule.new({"id" => "1"}), MatchingRule.new({"id" => "2", "tag" => "ruby"}), {id: 1, tag: "ruby"},
        Class.new(MatchingRule).new({"id" => "1", "tag" => "ruby"})].map { |other| rule == other }
    end

    def test_rules_of_another_tag_or_class_hash_apart
      rule = MatchingRule.new({"id" => "1", "tag" => "ruby"})

      refute_equal MatchingRule.new({"id" => "1"}).hash, rule.hash
      refute_equal Class.new(MatchingRule).new({"id" => "1", "tag" => "ruby"}).hash, rule.hash
    end

    def test_a_rule_refuses_what_is_not_one
      assert_raises(ArgumentError) { MatchingRule.new(nil) }
      assert_raises(ArgumentError) { MatchingRule.new({}) }
      assert_raises(ArgumentError) { MatchingRule.new({"id" => "0x1"}) }
      error = assert_raises(ArgumentError) { MatchingRule.new({"id" => "1", "tag" => :ruby}) }
      assert_equal "tag must be a String, not :ruby", error.message
    end
  end
end
