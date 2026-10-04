# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PinnedListsTest < Minitest::Test
    cover User
    cover Resources.const_get(:UserCollections)

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/pinned_lists", {"data" => [{"id" => "2", "name" => "Rubyists"}], "meta" => {"result_count" => 1}})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_pinned_lists_are_lists_of_the_user
      cursor = @user.pinned_lists

      assert_equal [List, "users/1/pinned_lists", @client], [cursor.resource_class, cursor.__send__(:path), cursor.client]
    end

    def test_pinned_lists_request_no_page_size
      assert_equal ["Rubyists"], @user.pinned_lists.first(3).map(&:name)
      refute @client.queries.first.key?("max_results")
      assert_equal List::FIELDS.join(","), @client.queries.first["list.fields"]
    end

    def test_pinned_lists_take_params
      @user.pinned_lists("list.fields": "name").to_a

      assert_equal "name", @client.queries.first["list.fields"]
    end
  end
end
