# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UserSearchTest < Minitest::Test
    cover User
    cover Objects.const_get(:UserCollections)
    cover X::Objects.const_get(:UserFinders)

    def setup
      @client = FakeClient.new
    end

    def test_search
      cursor = User.search("ruby", client: @client, max_results: 10)

      assert_equal "users/search", cursor.__send__(:path)
      assert_equal ["ruby", 10, "next_token"], [cursor.__send__(:params)["query"], cursor.__send__(:params)["max_results"], cursor.__send__(:token_param)]
      assert_same @client, cursor.client
    end

    def test_search_pages_with_next_token
      @client.stub(:get, "users/search", ->(query, _) { {"data" => [{"id" => query["next_token"].eql?("p2") ? "2" : "1"}], "meta" => {"next_token" => "p2"}.reject { query["next_token"] }} })

      assert_equal [1, 2], User.search("ruby", client: @client).map(&:id)
    end

    def test_search_defaults
      cursor = User.search("ruby", client: @client)

      assert_equal User, cursor.resource_class
      assert_equal 1000, cursor.__send__(:params)["max_results"]
      assert_equal User::FIELDS.join(","), cursor.__send__(:params)["user.fields"]
    end
  end
end
