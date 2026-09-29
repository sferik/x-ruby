# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class MatchingRulesTest < Minitest::Test
    cover Post
    cover Resource
    cover MatchingRule
    cover Objects::ValueEquality

    LINE = {"data" => {"id" => "1", "text" => "hello", "author_id" => "2"},
            "includes" => {"users" => [{"id" => "2", "username" => "sferik"}]},
            "matching_rules" => [{"id" => "1165037377523306498", "tag" => "ruby"}, {"id" => "1165037377523306499"}]}.freeze

    def test_a_post_of_the_filtered_stream_reads_the_rules_it_matched
      post = Post.from_response(LINE, client: nil)

      assert_equal [MatchingRule.new(id: 1_165_037_377_523_306_498, tag: "ruby"), MatchingRule.new(id: "1165037377523306499")], post.matching_rules
      assert_predicate post.matching_rules, :frozen?
      assert_equal ["hello", "sferik"], [post.text, post.author.username]
    end

    def test_a_post_keeps_the_rules_among_its_attributes
      post = Post.resource_from_response(LINE, client: nil)

      assert_equal LINE.fetch("data").merge(LINE.slice("matching_rules")), post.attrs
      assert_equal post.matching_rules, Marshal.load(Marshal.dump(post)).matching_rules
      assert_equal post.matching_rules, post.deconstruct_keys([:matching_rules]).fetch(:matching_rules)
    end

    def test_a_post_that_did_not_come_from_the_filtered_stream_matched_no_rule
      assert_empty Post.new({"id" => "1"}).matching_rules
      assert_predicate Post.new({"id" => "1"}).matching_rules, :frozen?
      refute Post.resource_from_response({"data" => {"id" => "1"}}, client: nil).attrs.key?("matching_rules")
    end

    def test_only_the_post_of_the_line_matched_the_rules
      line = LINE.merge("data" => {"id" => "1", "referenced_posts" => [{"type" => "quoted", "id" => "3"}]}, "includes" => {"posts" => [{"id" => "3"}]})

      assert_empty Post.from_response(line, client: nil).quoted.matching_rules
    end

    def test_rules_that_cannot_be_read
      messages = ["1", ["1"], [{"tag" => "ruby"}], [{"id" => "a"}], [{"id" => "1", "tag" => 1}]].map do |rules|
        assert_raises(InvalidAttribute) { Post.new({"id" => "1", "matching_rules" => rules}).matching_rules }.message
      end

      assert_equal ["X::Post#matching_rules cannot be read from \"1\"", "X::Post#matching_rules cannot be read from [\"1\"]",
        "X::Post#matching_rules cannot be read from #{{"tag" => "ruby"}.inspect}", "X::Post#matching_rules cannot be read from #{{"id" => "a"}.inspect}",
        "X::Post#matching_rules cannot be read from #{{"id" => "1", "tag" => 1}.inspect}"], messages
    end

    def test_a_rule
      rule = MatchingRule.new(id: "1165037377523306498", tag: +"ruby")

      assert_equal [1_165_037_377_523_306_498, "ruby"], [rule.id, rule.tag]
      assert_equal({id: 1_165_037_377_523_306_498, tag: "ruby"}, rule.deconstruct_keys(nil))
      assert_equal '#<X::MatchingRule id=1165037377523306498 tag="ruby">', rule.inspect
      assert_nil MatchingRule.new(id: 1).tag
    end

    def test_a_rule_holds_its_attributes_as_the_stream_sent_them
      rules = Post.from_response(LINE, client: nil).matching_rules

      assert_equal LINE.fetch("matching_rules"), rules.map(&:attrs)
      assert_equal({"id" => "1"}, MatchingRule.new(id: 1).to_h)
      assert_same rules.first.attrs, rules.first.to_h
      assert_predicate rules.first.attrs, :frozen?
    end

    def test_a_rule_is_serialized_by_its_attributes
      rule = MatchingRule.new(id: 1, tag: "ruby")

      assert_same rule.attrs, rule.as_json
      assert_equal "[{\"id\":\"1\",\"tag\":\"ruby\"}]", [rule].to_json
      assert_equal "{\"id\":\"2\"}", MatchingRule.new(id: 2).to_json
    end

    def test_a_rule_is_frozen_and_keeps_a_copy_of_its_tag
      tag = +"ruby"
      rule = MatchingRule.new(id: 1, tag:)
      tag << "!"

      assert_equal "ruby", rule.tag
      assert_predicate rule, :frozen?
      assert_predicate rule.tag, :frozen?
    end

    def test_a_rule_matches_a_pattern
      matched = [MatchingRule.new(id: 1, tag: "ruby"), MatchingRule.new(id: 2)].map do |rule|
        case rule
        in {id: 1, tag: "ruby"} then :ruby
        in {tag: nil} then :untagged
        end
      end

      assert_equal %i[ruby untagged], matched
    end

    def test_rules_of_the_same_identifier_and_tag_are_equal
      rule = MatchingRule.new(id: 1, tag: "ruby")

      assert_equal MatchingRule.new(id: "1", tag: "ruby"), rule
      assert rule.eql?(MatchingRule.new(id: 1, tag: "ruby"))
      assert_equal 1, [rule, MatchingRule.new(id: 1, tag: "ruby")].uniq.size
    end

    def test_rules_of_another_identifier_tag_or_class_are_not_equal
      rule = MatchingRule.new(id: 1, tag: "ruby")

      assert_equal [false] * 4, [MatchingRule.new(id: 1), MatchingRule.new(id: 2, tag: "ruby"), {id: 1, tag: "ruby"},
        Class.new(MatchingRule).new(id: 1, tag: "ruby")].map { |other| rule == other }
    end

    def test_rules_of_another_tag_or_class_hash_apart
      rule = MatchingRule.new(id: 1, tag: "ruby")

      refute_equal MatchingRule.new(id: 1).hash, rule.hash
      refute_equal Class.new(MatchingRule).new(id: 1, tag: "ruby").hash, rule.hash
    end

    def test_a_rule_refuses_what_is_not_one
      assert_raises(ArgumentError) { MatchingRule.new(id: nil) }
      assert_raises(ArgumentError) { MatchingRule.new(id: "0x1") }
      error = assert_raises(ArgumentError) { MatchingRule.new(id: 1, tag: :ruby) }
      assert_equal "tag must be a String, not :ruby", error.message
    end
  end
end
