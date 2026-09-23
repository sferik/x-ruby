# frozen_string_literal: true

require "json"
require "ostruct"
require_relative "../../test_helper"

module X
  # A rule is deleted by the identifier it was given, so the rules that were read delete themselves, or by the value
  # it matches, so the rules that were added delete what they added.
  class StreamingClientRuleDeletionTest < Minitest::Test
    cover StreamingClient

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body, method: :post, url: RULES_URL)
      stub_request(method, url).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_deleting_the_rules_that_were_read
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)

      assert_equal 2, @streaming_client.delete_stream_rules([RUBY_RULE, {"id" => "2"}])
      assert_requested(:post, RULES_URL, body: {delete: {ids: %w[1 2]}}.to_json)
    end

    def test_deleting_rules_by_identifier
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)

      assert_equal 2, @streaming_client.delete_stream_rules([1, {id: "2"}])
      assert_requested(:post, RULES_URL, body: {delete: {ids: [1, "2"]}}.to_json)
    end

    def test_deleting_rules_by_the_values_given_as_strings
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)

      assert_equal 2, @streaming_client.delete_stream_rules(["ruby", "2024"])
      assert_requested(:post, RULES_URL, body: {delete: {values: %w[ruby 2024]}}.to_json)
    end

    def test_deleting_what_add_stream_rules_was_given_deletes_what_it_added
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)
      @streaming_client.delete_stream_rules([{value: "ruby -is:retweet", tag: "ruby"}, "crystal"])

      assert_requested(:post, RULES_URL, body: {delete: {values: ["ruby -is:retweet", "crystal"]}}.to_json)
    end

    def test_deleting_no_rules_sends_no_request
      assert_equal [0, 0], [@streaming_client.delete_stream_rules([]), @streaming_client.delete_stream_rules([], dry_run: true)]
      assert_not_requested(:post, RULES_URL)
    end

    def test_deleting_rules_by_the_value_they_match
      stub_rules({"meta" => {"summary" => {"deleted" => 1}}}, method: :post)

      assert_equal 1, @streaming_client.delete_stream_rules({value: "ruby"})
      assert_requested(:post, RULES_URL, body: {delete: {values: ["ruby"]}}.to_json)
    end

    def test_deleting_rules_by_identifier_and_by_value_at_once
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)
      @streaming_client.delete_stream_rules([RUBY_RULE, {"value" => "crystal"}])

      assert_requested(:post, RULES_URL, body: {delete: {ids: ["1"], values: ["crystal"]}}.to_json)
    end

    def test_deleting_rules_that_are_only_checked
      stub_rules({"meta" => {"summary" => {"not_deleted" => 0, "deleted" => 1}}}, method: :post, url: "#{RULES_URL}?dry_run=true")

      assert_equal 1, @streaming_client.delete_stream_rules(1, dry_run: true)
    end

    def test_deleting_rules_the_api_reports_no_summary_for
      stub_rules({"meta" => {}}, method: :post)

      assert_equal 0, @streaming_client.delete_stream_rules(1)
    end

    def test_rules_written_with_symbol_keys_are_read_as_the_api_writes_them
      stub_rules({"meta" => {"summary" => {"deleted" => 2}}}, method: :post)
      @streaming_client.delete_stream_rules([{id: 1}, {value: "ruby"}])

      assert_requested(:post, RULES_URL, body: {delete: {ids: [1], values: ["ruby"]}}.to_json)
    end

    def test_a_response_of_no_content_holds_no_rules_and_deletes_none
      stub_request(:post, RULES_URL).to_return(status: 204, body: "", headers: {"Content-Type" => "application/json"})
      stub_request(:get, RULES_URL).to_return(status: 204, body: "", headers: {"Content-Type" => "application/json"})

      assert_empty @streaming_client.stream_rules
      assert_empty @streaming_client.add_stream_rules("ruby")
      assert_equal 0, @streaming_client.delete_stream_rules(1)
    end

    def test_a_response_that_summarizes_nothing_deletes_none
      stub_rules({"data" => []}, method: :post)

      assert_equal 0, @streaming_client.delete_stream_rules(1)
    end

    def test_the_rules_changed_are_hashes_whatever_the_client_parses_into
      stub_rules({"data" => [RUBY_RULE], "meta" => {"summary" => {"deleted" => 1}}}, method: :post)
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct, default_array_class: Set).streaming

      assert_equal [RUBY_RULE], streaming_client.add_stream_rules("ruby")
      assert_equal 1, streaming_client.delete_stream_rules(1)
    end

    def test_deleting_something_that_is_neither_a_rule_nor_an_identifier
      error = assert_raises(ArgumentError) { @streaming_client.delete_stream_rules({"tag" => "ruby"}) }

      assert_equal 'a rule is a Hash holding an id or a value, the value it matches, or its identifier, not {"tag" => "ruby"}', error.message
    end

    def test_deleting_something_that_is_neither_a_hash_a_string_nor_an_integer
      [:ruby, nil, 1.0].each do |rule|
        error = assert_raises(ArgumentError) { @streaming_client.delete_stream_rules([rule]) }

        assert_equal "a rule is a Hash holding an id or a value, the value it matches, or its identifier, not #{rule.inspect}", error.message
      end
      assert_not_requested(:post, RULES_URL)
    end

    def test_a_client_that_cannot_authenticate_as_the_app_deletes_none
      streaming_client = Client.new(**test_oauth2_credentials).streaming

      assert_raises(UnsupportedOperation) { streaming_client.delete_stream_rules(1) }
    end
  end
end
