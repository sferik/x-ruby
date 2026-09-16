require "json"
require_relative "../../test_helper"

module X
  class ClientParamsTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new
    end

    def test_get_with_params
      stub_request(:get, "https://api.twitter.com/2/users?ids=1,2&user.fields=id,username")
      @client.get("users", params: {ids: [1, 2], "user.fields": %w[id username]})

      assert_requested :get, "https://api.twitter.com/2/users?ids=1,2&user.fields=id,username"
    end

    def test_params_join_array_subclasses
      stub_request(:get, "https://api.twitter.com/2/users?ids=1,2")
      @client.get("users", params: {ids: Class.new(Array).new([1, 2])})

      assert_requested :get, "https://api.twitter.com/2/users?ids=1,2"
    end

    def test_params_drop_nil_values
      stub_request(:get, "https://api.twitter.com/2/users?ids=1")
      @client.get("users", params: {ids: 1, expansions: nil})

      assert_requested :get, "https://api.twitter.com/2/users?ids=1"
    end

    def test_params_extend_an_existing_query_string
      stub_request(:get, "https://api.twitter.com/2/users?ids=1&max_results=5")
      @client.get("users?ids=1", params: {max_results: 5})

      assert_requested :get, "https://api.twitter.com/2/users?ids=1&max_results=5"
    end

    def test_empty_params_leave_the_endpoint_alone
      stub_request(:get, "https://api.twitter.com/2/users/me")
      @client.get("users/me", params: {})
      @client.get("users/me", params: {expansions: nil})

      assert_requested :get, "https://api.twitter.com/2/users/me", times: 2
    end

    def test_params_are_encoded
      stub_request(:get, "https://api.twitter.com/2/tweets/search/recent?query=ruby%20-is:retweet")
      @client.get("tweets/search/recent", params: {query: "ruby -is:retweet"})

      assert_requested :get, "https://api.twitter.com/2/tweets/search/recent?query=ruby%20-is:retweet"
    end

    def test_delete_with_params
      stub_request(:delete, "https://api.twitter.com/2/tweets/1?force=true")
      @client.delete("tweets/1", params: {force: true})

      assert_requested :delete, "https://api.twitter.com/2/tweets/1?force=true"
    end

    def test_post_with_params
      stub_request(:post, "https://api.twitter.com/2/tweets?dry_run=true")
      @client.post("tweets", params: {dry_run: true})

      assert_requested :post, "https://api.twitter.com/2/tweets?dry_run=true"
    end

    def test_put_with_params
      stub_request(:put, "https://api.twitter.com/2/tweets?dry_run=true")
      @client.put("tweets", params: {dry_run: true})

      assert_requested :put, "https://api.twitter.com/2/tweets?dry_run=true"
    end
  end
end
