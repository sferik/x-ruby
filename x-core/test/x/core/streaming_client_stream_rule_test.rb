# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # A rule the API returned is a StreamRule, which adds itself by its value and tag, and deletes itself by the
  # identifier the API gave it, or by its value when it holds none
  class StreamingClientStreamRuleTest < Minitest::Test
    cover StreamingClient
    cover Core::StreamRules

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze
    RUBY_STREAM_RULE = StreamRule.new(id: 1, value: "ruby -is:retweet", tag: "ruby")

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body, method: :post, url: RULES_URL)
      stub_request(method, url).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_adding_rules_that_were_read
      stub_rules({"data" => [RUBY_RULE]}, method: :post)
      @streaming_client.add_rules([RUBY_STREAM_RULE, StreamRule.new(value: "crystal")])

      assert_requested(:post, RULES_URL, body: {add: [{value: "ruby -is:retweet", tag: "ruby"}, {value: "crystal"}]}.to_json)
    end

    def test_deleting_the_stream_rules_that_were_read_by_identifier
      stub_rules({"meta" => {"summary" => {"deleted" => 1}}}, method: :post)

      assert_equal 1, @streaming_client.delete_rules(StreamRule.new(id: 1165037377523306498, value: "ruby"))
      assert_requested(:post, RULES_URL, body: {delete: {ids: ["1165037377523306498"]}}.to_json)
    end

    def test_deleting_stream_rules_that_hold_no_identifier_by_value
      stub_rules({"meta" => {"summary" => {"deleted" => 1}}}, method: :post)
      @streaming_client.delete_rules([StreamRule.new(value: "ruby", tag: "ruby")])

      assert_requested(:post, RULES_URL, body: {delete: {values: ["ruby"]}}.to_json)
    end

    def test_a_subclass_of_stream_rule_is_a_rule
      rule_class = Class.new(StreamRule)
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)
      @streaming_client.delete_rules([rule_class.new(id: 1, value: "ruby"), rule_class.new(value: "crystal")])
      @streaming_client.add_rules(rule_class.new(value: "ruby", tag: "ruby"))

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["1"], values: ["crystal"]}}.to_json)
      assert_requested(:post, RULES_URL, body: {add: [{value: "ruby", tag: "ruby"}]}.to_json)
    end

    def test_a_rule_a_response_holds_without_a_value_is_refused
      stub_rules({"data" => [{"id" => "1"}]}, method: :get)

      assert_equal "value must be a String, not nil", assert_raises(ArgumentError) { @streaming_client.rules }.message
    end

    def test_adding_no_rules_sends_no_request
      added = [@streaming_client.add_rules([]), @streaming_client.add_rules([], dry_run: true) { |_| flunk }]

      assert_equal [[], []], added
      assert added.all?(&:frozen?)
      assert_not_requested(:post, RULES_URL)
    end

    def test_the_identifier_a_hash_holds_is_not_sent_with_a_rule_to_add
      stub_rules({"data" => []})
      @streaming_client.add_rules([{"id" => "1", "value" => "ruby"}, {id: 2, value: "crystal"}])

      assert_requested(:post, RULES_URL, body: {add: [{"value" => "ruby"}, {value: "crystal"}]}.to_json)
    end
  end
end
