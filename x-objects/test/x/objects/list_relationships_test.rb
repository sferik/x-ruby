# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ListRelationshipsTest < Minitest::Test
    cover Objects::Relationships

    def setup
      @client = FakeClient.new
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_follow_list
      @client.stub(:post, "users/9/followed_lists", {"data" => {"following" => true}})

      assert @me.follow_list(List.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/followed_lists", query: {}, body: {list_id: "1"}.to_json}], @client.requests
    end

    def test_follow_list_not_following
      @client.stub(:post, "users/9/followed_lists", {"data" => {"following" => false}})

      refute @me.follow_list(1)
    end

    def test_unfollow_list
      @client.stub(:delete, "users/9/followed_lists/1", {"data" => {"following" => false}})

      assert @me.unfollow_list(List.new({"id" => "1"}))
      assert_equal ["users/9/followed_lists/1"], @client.paths
    end

    def test_unfollow_list_still_following
      @client.stub(:delete, "users/9/followed_lists/1", {"data" => {"following" => true}})

      refute @me.unfollow_list("1")
    end

    def test_pin_list
      @client.stub(:post, "users/9/pinned_lists", {"data" => {"pinned" => true}})

      assert @me.pin_list(List.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/pinned_lists", query: {}, body: {list_id: "1"}.to_json}], @client.requests
    end

    def test_pin_list_not_pinned
      @client.stub(:post, "users/9/pinned_lists", {"data" => {"pinned" => false}})

      refute @me.pin_list(1)
    end

    def test_unpin_list
      @client.stub(:delete, "users/9/pinned_lists/1", {"data" => {"pinned" => false}})

      assert @me.unpin_list(List.new({"id" => "1"}))
      assert_equal ["users/9/pinned_lists/1"], @client.paths
    end

    def test_unpin_list_still_pinned
      @client.stub(:delete, "users/9/pinned_lists/1", {"data" => {"pinned" => true}})

      refute @me.unpin_list("1")
    end
  end

  class PinnedListsTest < Minitest::Test
    cover User

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/pinned_lists", {"data" => [{"id" => "2", "name" => "Rubyists"}], "meta" => {"result_count" => 1}})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_pinned_lists_are_lists_of_the_user
      cursor = @user.pinned_lists

      assert_equal [List, "users/1/pinned_lists", @client], [cursor.resource_class, cursor.path, cursor.client]
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
