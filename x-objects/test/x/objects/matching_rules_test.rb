# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class MatchingRulesTest < Minitest::Test
    cover Post
    cover Resource
    cover MatchingRule

    LINE = {"data" => {"id" => "1", "text" => "hello", "author_id" => "2"},
            "includes" => {"users" => [{"id" => "2", "username" => "sferik"}]},
            "matching_rules" => [{"id" => "1165037377523306498", "tag" => "ruby"}, {"id" => "1165037377523306499"}]}.freeze

    def test_a_post_of_the_filtered_stream_reads_the_rules_it_matched
      post = Post.from_response(LINE, client: nil)

      assert_equal [MatchingRule.new({"id" => "1165037377523306498", "tag" => "ruby"}), MatchingRule.new({"id" => "1165037377523306499"})], post.matching_rules
      assert_predicate post.matching_rules, :frozen?
      assert_equal ["hello", "sferik"], [post.text, post.author.username]
    end

    def test_a_post_keeps_the_rules_among_its_attributes
      post = Post.__send__(:resource_from_response, LINE, client: nil)

      assert_equal LINE.fetch("data").merge(LINE.slice("matching_rules")), post.attrs
      assert_equal post.matching_rules, Marshal.load(Marshal.dump(post)).matching_rules
      assert_equal post.matching_rules, post.deconstruct_keys([:matching_rules]).fetch(:matching_rules)
    end

    def test_a_post_that_did_not_come_from_the_filtered_stream_matched_no_rule
      assert_empty Post.new({"id" => "1"}).matching_rules
      assert_predicate Post.new({"id" => "1"}).matching_rules, :frozen?
      refute Post.__send__(:resource_from_response, {"data" => {"id" => "1"}}, client: nil).attrs.key?("matching_rules")
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

    def test_a_rule_holds_its_attributes_as_the_stream_sent_them
      rules = Post.from_response(LINE, client: nil).matching_rules

      assert_equal LINE.fetch("matching_rules"), rules.map(&:attrs)
      assert_same rules.first.attrs, rules.first.to_h
      assert_predicate rules.first.attrs, :frozen?
    end

    def test_a_rule_keeps_what_the_stream_sends_of_it_beside_its_identifier_and_tag
      line = LINE.merge("matching_rules" => [{"id" => "1", "tag" => "ruby", "value" => "ruby lang:en"}])
      rule = Post.from_response(line, client: nil).matching_rules.first

      assert_equal({"id" => "1", "tag" => "ruby", "value" => "ruby lang:en"}, rule.to_h)
      assert_equal [1, "ruby"], [rule.id, rule.tag]
    end
  end
end
