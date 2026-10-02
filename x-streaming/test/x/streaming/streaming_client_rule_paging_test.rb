# frozen_string_literal: true

require "json"
require_relative "../../test_helper"

module X
  # The rules of the filtered stream are read a page at a time, and a page that names no page after it is the last, as
  # is one that names an empty token or the token of a page already read, which would have the pages requested again.
  class StreamingClientRulePagingTest < Minitest::Test
    cover StreamingClient
    cover Streaming.const_get(:StreamRules)

    RULES_URL = "https://api.x.com/2/tweets/search/stream/rules"
    RUBY_RULE = {"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}.freeze
    RUBY_STREAM_RULE = StreamRule.new(id: 1, value: "ruby -is:retweet", tag: "ruby")

    def setup
      @streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def stub_rules(body, url: RULES_URL)
      stub_request(:get, url).to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def test_a_page_that_names_an_empty_next_token_is_the_last
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => ""}})

      assert_equal [RUBY_STREAM_RULE], @streaming_client.rules
      assert_requested(:get, RULES_URL, times: 1)
    end

    def test_a_page_that_names_the_token_of_a_page_already_read_is_the_last
      crystal = {"id" => "2", "value" => "crystal"}
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => "PAGE2"}})
      stub_rules({"data" => [crystal], "meta" => {"next_token" => "PAGE2"}}, url: "#{RULES_URL}?pagination_token=PAGE2")

      assert_equal [RUBY_STREAM_RULE, StreamRule.new(id: 2, value: "crystal")], @streaming_client.rules
      assert_requested(:get, "#{RULES_URL}?pagination_token=PAGE2", times: 1)
    end

    def test_a_page_that_names_a_token_that_fetched_a_page_before_the_last_is_the_last
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => "PAGE2"}})
      stub_rules({"meta" => {"next_token" => "PAGE3"}}, url: "#{RULES_URL}?pagination_token=PAGE2")
      stub_rules({"meta" => {"next_token" => "PAGE2"}}, url: "#{RULES_URL}?pagination_token=PAGE3")

      assert_equal [RUBY_STREAM_RULE], @streaming_client.rules
      assert_requested(:get, "#{RULES_URL}?pagination_token=PAGE2", times: 1)
    end

    def test_the_next_token_takes_the_place_of_a_pagination_token_named_by_a_string
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => "PAGE3"}}, url: "#{RULES_URL}?pagination_token=PAGE2")
      stub_rules({"meta" => {"result_count" => 0}}, url: "#{RULES_URL}?pagination_token=PAGE3")

      assert_equal [RUBY_STREAM_RULE], @streaming_client.rules(params: {"pagination_token" => "PAGE2"})
      assert_requested(:get, "#{RULES_URL}?pagination_token=PAGE3") { |request| request.uri.query.eql?("pagination_token=PAGE3") }
    end

    def test_the_next_token_takes_the_place_of_a_pagination_token_named_by_a_symbol
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => "PAGE3"}}, url: "#{RULES_URL}?ids=1&pagination_token=PAGE2")
      stub_rules({"meta" => {"result_count" => 0}}, url: "#{RULES_URL}?ids=1&pagination_token=PAGE3")

      assert_equal [RUBY_STREAM_RULE], @streaming_client.rules(params: {ids: 1, pagination_token: "PAGE2"})
    end

    def test_a_stop_iteration_on_response_raises_while_a_page_is_read_reaches_the_caller
      stub_rules({"data" => [RUBY_RULE], "meta" => {"next_token" => "PAGE2"}})
      stub_rules({"data" => [{"id" => "2", "value" => "crystal"}]}, url: "#{RULES_URL}?pagination_token=PAGE2")
      on_response = ->(response) { raise StopIteration if response.uri.query }
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response:).streaming

      assert_raises(StopIteration) { streaming_client.rules }
      assert_requested(:get, "#{RULES_URL}?pagination_token=PAGE2", times: 1)
    end
  end
end
