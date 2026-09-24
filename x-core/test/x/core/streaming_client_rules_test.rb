# frozen_string_literal: true

require "json"
require "ostruct"
require_relative "../../test_helper"

module X
  # The rules of the filtered stream belong to the stream, so they are read and changed through a streaming client,
  # which authenticates as the app for them as it does for the stream itself.
  class StreamingClientRulesTest < Minitest::Test
    cover StreamingClient

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body, method: :get, url: RULES_URL)
      stub_request(method, url).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_the_rules_of_the_app
      stub_rules({"data" => [RUBY_RULE], "meta" => {"result_count" => 1}})

      assert_equal [RUBY_RULE], @streaming_client.stream_rules
    end

    def test_an_app_with_no_rules_has_none
      stub_rules({"meta" => {"result_count" => 0}})

      assert_empty @streaming_client.stream_rules
    end

    def test_the_rules_are_read_as_the_app
      stub_rules({"data" => [RUBY_RULE]})
      @streaming_client.stream_rules

      assert_requested(:get, RULES_URL) { |request| request.headers["Authorization"].eql?("Bearer #{TEST_BEARER_TOKEN}") }
    end

    def test_the_rules_take_query_parameters
      stub_rules({"data" => [RUBY_RULE]}, url: "#{RULES_URL}?ids=1")

      assert_equal [RUBY_RULE], @streaming_client.stream_rules(params: {ids: 1})
    end

    def test_the_rules_are_hashes_whatever_the_client_parses_into
      stub_rules({"data" => [RUBY_RULE]})
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct).streaming

      assert_equal [RUBY_RULE], streaming_client.stream_rules
    end

    def test_adding_a_rule
      stub_rules({"data" => [RUBY_RULE], "meta" => {"summary" => {"created" => 1}}}, method: :post)

      assert_equal [RUBY_RULE], @streaming_client.add_stream_rules({value: "ruby -is:retweet", tag: "ruby"})
      assert_requested(:post, RULES_URL, body: {add: [{value: "ruby -is:retweet", tag: "ruby"}]}.to_json)
    end

    def test_adding_rules_named_by_the_values_they_match
      stub_rules({"data" => []}, method: :post)
      @streaming_client.add_stream_rules(%w[ruby crystal])

      assert_requested(:post, RULES_URL, body: {add: [{value: "ruby"}, {value: "crystal"}]}.to_json)
    end

    def test_adding_rules_that_are_only_checked
      stub_rules({"data" => [RUBY_RULE]}, method: :post, url: "#{RULES_URL}?dry_run=true")

      assert_equal [RUBY_RULE], @streaming_client.add_stream_rules("ruby", dry_run: true)
    end

    def test_adding_rules_the_api_reports_nothing_for
      stub_rules({"meta" => {"summary" => {"created" => 0}}}, method: :post)

      assert_empty @streaming_client.add_stream_rules("ruby")
    end

    def test_adding_something_that_is_not_a_rule
      error = assert_raises(ArgumentError) { @streaming_client.add_stream_rules({"tag" => "ruby"}) }

      assert_equal 'a rule to add is a Hash holding a value, or the value it matches, not {"tag" => "ruby"}', error.message
    end

    def test_adding_something_that_is_neither_a_hash_nor_a_string
      [42, :ruby, nil, {id: "1"}, {value: nil}, {"value" => nil}].each do |rule|
        error = assert_raises(ArgumentError) { @streaming_client.add_stream_rules(["ruby", rule]) }

        assert_equal "a rule to add is a Hash holding a value, or the value it matches, not #{rule.inspect}", error.message
      end
      assert_not_requested(:post, RULES_URL)
    end

    def test_adding_a_rule_with_its_value_under_a_string_key
      stub_rules({"data" => []}, method: :post)
      @streaming_client.add_stream_rules({"value" => "ruby"})

      assert_requested(:post, RULES_URL, body: {add: [{value: "ruby"}]}.to_json)
    end

    def test_adding_no_rules_sends_no_request
      assert_equal [[], []], [@streaming_client.add_stream_rules([]), @streaming_client.add_stream_rules([], dry_run: true)]
      assert_not_requested(:post, RULES_URL)
    end

    def test_the_rules_of_a_client_that_cannot_authenticate_as_the_app
      streaming_client = Client.new(**test_oauth2_credentials).streaming

      assert_raises(UnsupportedOperation) { streaming_client.stream_rules }
      assert_raises(UnsupportedOperation) { streaming_client.add_stream_rules("ruby") }
    end
  end
end
