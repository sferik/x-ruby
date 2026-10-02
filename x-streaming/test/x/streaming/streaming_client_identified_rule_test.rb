# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # Anything with an id names a rule to delete by its identifier, as the X::MatchingRule each post of x-objects names in
  # matching_rules does, which holds the identifier and tag of a rule but not its value, and which x-streaming does
  # not depend on
  class StreamingClientIdentifiedRuleTest < Minitest::Test
    cover StreamingClient
    cover Streaming.const_get(:StreamRules)
    cover Streaming.const_get(:Validator)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    # A rule a post matched, as x-objects reads one: its identifier and its tag, and no value
    MatchedRule = Struct.new(:id, :tag)

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
      stub_request(:post, RULES_URL).to_return(body: {"meta" => {"summary" => {"deleted" => 2}}}.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_deleting_the_rules_a_post_matched_by_identifier
      assert_equal 2, @streaming_client.delete_rules([MatchedRule.new(1165037377523306498, "ruby"), MatchedRule.new("2", nil)])
      assert_requested(:post, RULES_URL, body: {delete: {ids: %w[1165037377523306498 2]}}.to_json)
    end

    def test_deleting_one_rule_with_an_id
      rule = Object.new
      rule.define_singleton_method(:id) { 7 }
      @streaming_client.delete_rules(rule)

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["7"]}}.to_json)
    end

    def test_deleting_rules_with_an_id_beside_rules_named_by_value
      @streaming_client.delete_rules([MatchedRule.new(1, "ruby"), "crystal"])

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["1"], values: ["crystal"]}}.to_json)
    end

    def test_a_rule_whose_id_is_nil_is_refused
      rule = MatchedRule.new(nil, "ruby")
      error = assert_raises(ArgumentError) { @streaming_client.delete_rules([rule]) }

      assert_equal "a rule is a StreamRule, a Hash holding an id or a value, anything with an id, the value it matches, or its identifier, not #{rule.inspect}", error.message
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_rule_whose_id_is_not_an_identifier_is_refused
      error = assert_raises(ArgumentError) { @streaming_client.delete_rules([MatchedRule.new(" 1_0 ", "ruby")]) }

      assert_equal 'invalid value for Integer(): " 1_0 "', error.message
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_rule_with_an_id_is_not_a_rule_to_add
      error = assert_raises(ArgumentError) { @streaming_client.add_rules([MatchedRule.new(1, "ruby")]) }

      assert_equal "a rule to add is a StreamRule, a Hash holding a value, or the value it matches, not #<struct X::StreamingClientIdentifiedRuleTest::MatchedRule id=1, tag=\"ruby\">", error.message
    end
  end
end
