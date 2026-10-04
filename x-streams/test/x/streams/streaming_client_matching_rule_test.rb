# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # The X::MatchingRule each post of x-resources names in matching_rules, which holds the identifier and tag of a rule but
  # not its value, names a rule to delete by its identifier, and x-streams does not depend on x-resources; anything
  # else with an id, such as a post, names no rule
  class StreamingClientMatchingRuleTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:StreamRules)
    cover Streams.const_get(:Validator)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    # A rule a post matched, as x-resources reads one: its identifier and its tag, and no value
    MatchedRule = Data.define(:id, :tag)
    # A post, which has an id as a rule does, but names no rule
    Post = Data.define(:id, :text)

    def setup
      X.const_set(:MatchingRule, MatchedRule)
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
      stub_request(:post, RULES_URL).to_return(body: {"meta" => {"summary" => {"deleted" => 2}}}.to_json, headers: {"Content-Type" => "application/json"})
    end

    def teardown
      X.send(:remove_const, :MatchingRule)
      super
    end

    def test_deleting_the_rules_a_post_matched_by_identifier
      assert_equal 2, @streaming_client.delete_rules([MatchedRule.new(1165037377523306498, "ruby"), MatchedRule.new("2", nil)])
      assert_requested(:post, RULES_URL, body: {delete: {ids: %w[1165037377523306498 2]}}.to_json)
    end

    def test_deleting_one_rule_a_post_matched
      @streaming_client.delete_rules(MatchedRule.new(7, "ruby"))

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["7"]}}.to_json)
    end

    def test_deleting_a_rule_of_a_kind_of_matching_rule
      @streaming_client.delete_rules(Class.new(MatchedRule).new(7, "ruby"))

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["7"]}}.to_json)
    end

    def test_deleting_rules_a_post_matched_beside_rules_named_by_value
      @streaming_client.delete_rules([MatchedRule.new(1, "ruby"), "crystal"])

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["1"], values: ["crystal"]}}.to_json)
    end

    def test_a_post_with_an_id_is_refused
      post = Post.new(1165037377523306498, "ruby")
      error = assert_raises(ArgumentError) { @streaming_client.delete_rules([MatchedRule.new(1, "ruby"), post]) }

      assert_equal "a rule is a StreamRule, a Hash holding an id or a value, an X::MatchingRule, the value it matches, or its identifier, not #{post.inspect}", error.message
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_matching_rule_of_another_namespace_is_refused
      Streams.const_set(:MatchingRule, Data.define(:id, :tag))
      rule = Streams.const_get(:MatchingRule).new(1, "ruby")

      assert_raises(ArgumentError) { @streaming_client.delete_rules(rule) }
      assert_not_requested(:post, RULES_URL)
    ensure
      Streams.send(:remove_const, :MatchingRule)
    end

    def test_a_rule_whose_id_is_nil_is_refused
      rule = MatchedRule.new(nil, "ruby")
      error = assert_raises(ArgumentError) { @streaming_client.delete_rules([rule]) }

      assert_equal "a rule is a StreamRule, a Hash holding an id or a value, an X::MatchingRule, the value it matches, or its identifier, not #{rule.inspect}", error.message
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_rule_whose_id_is_not_an_identifier_is_refused
      error = assert_raises(ArgumentError) { @streaming_client.delete_rules([MatchedRule.new(" 1_0 ", "ruby")]) }

      assert_equal 'invalid value for Integer(): " 1_0 "', error.message
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_rule_a_post_matched_is_not_a_rule_to_add
      error = assert_raises(ArgumentError) { @streaming_client.add_rules([MatchedRule.new(1, "ruby")]) }

      assert_equal "a rule to add is a StreamRule, a Hash holding a value, or the value it matches, not #<data X::StreamingClientMatchingRuleTest::MatchedRule id=1, tag=\"ruby\">", error.message
    end
  end

  # Without x-resources, which defines X::MatchingRule, nothing but a StreamRule, a Hash, a String, or an Integer names a
  # rule to delete
  class StreamingClientWithoutMatchingRuleTest < Minitest::Test
    cover Streams.const_get(:StreamRules)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"

    def test_something_with_an_id_is_refused
      rule = Data.define(:id, :tag).new(1, "ruby")
      error = assert_raises(ArgumentError) { Client.new(bearer_token: TEST_BEARER_TOKEN).streaming.delete_rules(rule) }

      assert_equal "a rule is a StreamRule, a Hash holding an id or a value, an X::MatchingRule, the value it matches, or its identifier, not #{rule.inspect}", error.message
      assert_not_requested(:post, RULES_URL)
    end
  end
end
