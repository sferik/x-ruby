# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # A rule the app already has is not one the API rejected: it exists, which is what add_rules was asked for, so it
  # raises nothing, so that the rules of an app are added each time it boots, and is not among the rules returned,
  # which are the rules the API added alone, since the API reports neither its tag nor, always, its identifier
  class StreamingClientDuplicateRuleTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:StreamRules)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze
    RUBY_STREAM_RULE = StreamRule.new(id: 1, value: "ruby -is:retweet", tag: "ruby")
    # The error X reports of a rule whose value an app already has a rule of, which holds no tag of the rule it kept
    DUPLICATE = {"value" => "crystal", "id" => "1166895166390583299", "title" => "DuplicateRule",
                 "type" => "https://api.twitter.com/2/problems/duplicate-rules"}.freeze
    INVALID = {"value" => "from:", "title" => "UnprocessableEntity", "detail" => "Rule is invalid",
               "type" => "https://api.twitter.com/2/problems/invalid-rules"}.freeze

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body, url: RULES_URL)
      stub_request(:post, url).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_rules_the_app_already_has_raise_nothing_and_none_is_returned
      stub_rules({"meta" => {"summary" => {"created" => 0, "not_created" => 1, "valid" => 0, "invalid" => 1}}, "errors" => [DUPLICATE]})

      rules = @streaming_client.add_rules(["crystal"])

      assert_equal [[], true], [rules, rules.frozen?]
    end

    def test_only_the_rules_that_were_added_are_returned_beside_a_rule_the_app_already_had
      stub_rules({"data" => [RUBY_RULE], "errors" => [DUPLICATE], "meta" => {"summary" => {"created" => 1, "not_created" => 1}}})

      rules = @streaming_client.add_rules([{value: "ruby -is:retweet", tag: "ruby"}, "crystal"])

      assert_equal [[RUBY_STREAM_RULE], true], [rules, rules.frozen?]
    end

    def test_a_block_is_yielded_the_problem_of_the_rule_the_app_already_had_which_is_not_returned
      stub_rules({"data" => [RUBY_RULE], "errors" => [DUPLICATE]})
      problems = []

      assert_equal [RUBY_STREAM_RULE], @streaming_client.add_rules(%w[ruby crystal]) { |problem| problems << problem }
      assert_equal [Problem.new(DUPLICATE)], problems
      assert_equal ["crystal", "DuplicateRule", "1166895166390583299"], problems.first.then { |problem| [problem.value, problem.title, problem.attrs["id"]] }
    end

    def test_a_rule_the_api_rejected_beside_one_the_app_already_has_raises_for_the_rejected_rule_alone
      stub_rules({"data" => [RUBY_RULE], "errors" => [DUPLICATE, INVALID]})
      error = assert_raises(RulesRejected) { @streaming_client.add_rules(%w[ruby crystal from:]) }

      assert_equal [[Problem.new(INVALID)], [RUBY_STREAM_RULE]], [error.problems, error.added]
      assert_equal "UnprocessableEntity: Rule is invalid", error.message
    end

    def test_a_block_is_yielded_every_problem_in_the_order_the_api_reported_them
      stub_rules({"errors" => [INVALID, DUPLICATE]})
      problems = []

      assert_empty(@streaming_client.add_rules(%w[from: crystal]) { |problem| problems << problem.title })
      assert_equal %w[UnprocessableEntity DuplicateRule], problems
    end

    def test_a_rule_a_dry_run_finds_the_app_already_has_raises_nothing_and_is_not_returned
      request = stub_rules({"errors" => [DUPLICATE]}, url: "#{RULES_URL}?dry_run=true")

      assert_empty @streaming_client.add_rules("crystal", dry_run: true)
      assert_requested request
    end

    # A problem is told by its type, as an operational-disconnect is, rather than by a title, which says it to a reader
    def test_a_problem_is_one_of_a_rule_the_app_already_has_by_its_type
      stub_rules({"errors" => [DUPLICATE.except("type"), DUPLICATE.merge("type" => "https://api.twitter.com/2/problems/duplicate-rules/other")]})
      error = assert_raises(RulesRejected) { @streaming_client.add_rules(%w[crystal crystal]) }

      assert_equal [%w[DuplicateRule DuplicateRule], []], [error.problems.map(&:title), error.added]
    end
  end
end
