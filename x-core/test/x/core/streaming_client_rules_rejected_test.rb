# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # The rules the API did not change are yielded to a block, and raise without one, rather than be dropped
  class StreamingClientRulesRejectedTest < Minitest::Test
    cover StreamingClient
    cover Core.const_get(:StreamRules)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body)
      stub_request(:post, RULES_URL).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_rules_the_api_does_not_add_raise_without_a_block
      duplicate = {"value" => "crystal", "id" => "2", "title" => "DuplicateRule", "detail" => "Duplicate rule"}
      stub_rules({"data" => [RUBY_RULE], "errors" => [duplicate], "meta" => {"summary" => {"created" => 1, "not_created" => 1}}})
      error = assert_raises(RulesRejected) { @streaming_client.add_rules(%w[ruby crystal]) }

      assert_equal [[StreamRule.new(id: 1, value: "ruby -is:retweet", tag: "ruby")], ["crystal"]], [error.result, error.problems.map(&:value)]
      assert_equal "DuplicateRule: Duplicate rule", error.message
    end

    def test_rules_a_dry_run_finds_invalid_raise_without_a_block
      invalid = {"value" => "from:", "title" => "UnprocessableEntity", "detail" => "Rule is invalid"}
      stub_request(:post, "#{RULES_URL}?dry_run=true").to_return(body: {"errors" => [invalid]}.to_json, headers: {"Content-Type" => "application/json"})
      error = assert_raises(RulesRejected) { @streaming_client.add_rules("from:", dry_run: true) }

      assert_equal [[], ["from:"]], [error.result, error.problems.map(&:value)]
    end

    def test_rules_the_api_does_not_delete_raise_without_a_block
      missing = {"errors" => [{"parameters" => {}, "message" => "Rule does not exist"}], "title" => "Invalid Request",
                 "detail" => "One or more parameters to your request was invalid.", "type" => "https://api.x.com/2/problems/invalid-request"}
      stub_rules({"errors" => [missing], "meta" => {"summary" => {"deleted" => 1, "not_deleted" => 1}}})
      error = assert_raises(RulesRejected) { @streaming_client.delete_rules([RUBY_RULE, {"id" => "2"}]) }

      assert_equal [1, [missing]], [error.result, error.problems.map(&:to_h)]
    end

    def test_a_block_takes_the_problems_in_place_of_the_error
      stub_rules({"errors" => [{"value" => "crystal", "title" => "DuplicateRule"}]})

      assert_empty @streaming_client.add_rules("crystal") { |_| nil }
    end
  end
end
