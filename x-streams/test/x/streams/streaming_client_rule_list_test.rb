# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Only an Array is read as a list of rules, so a Struct given as one rule is refused as one, rather than read as the
  # list of its members, which would add its tag as a rule or delete the rule of its identifier
  class StreamingClientRuleListTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:StreamRules)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def test_a_struct_of_a_value_and_a_tag_is_refused_as_a_rule_to_add
      rule = Struct.new(:value, :tag).new("ruby -is:retweet", "ruby")

      assert_raises(ArgumentError) { @streaming_client.add_rules(rule) }
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_struct_of_an_identifier_and_a_text_is_refused_as_a_rule_to_delete
      row = Struct.new(:id, :text).new(1234, "a post")

      assert_raises(ArgumentError) { @streaming_client.delete_rules(row) }
      assert_not_requested(:post, RULES_URL)
    end

    def test_nil_is_no_rules_to_add_or_delete
      assert_equal [[], 0], [@streaming_client.add_rules(nil), @streaming_client.delete_rules(nil)]
      assert_not_requested(:post, RULES_URL)
    end
  end
end
