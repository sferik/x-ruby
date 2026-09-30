# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ListTest < Minitest::Test
    cover List
    cover Objects.const_get(:Finders)
    cover Objects.const_get(:BatchFinders)

    def setup
      @client = FakeClient.new
      includes = Objects.const_get(:Includes).new({"users" => [{"id" => "9", "username" => "sferik"}]})
      @list = List.__send__(:build, {"id" => "1", "name" => "Ruby", "description" => "d", "created_at" => "2024-01-02T03:04:05.000Z",
                        "follower_count" => 2, "member_count" => 3, "owner_id" => "9", "private" => true},
        client: @client, includes:)
    end

    def test_class_configuration
      assert_equal "lists", List.__send__(:endpoint)
      assert_nil List.__send__(:includes_key)
      assert_equal({"list.fields" => List::FIELDS, "user.fields" => User::FIELDS, "expansions" => List::EXPANSIONS}, List.default_params)
    end

    def test_attributes
      assert_equal "Ruby", @list.name
      assert_equal "d", @list.description
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @list.created_at
      assert_equal 2, @list.follower_count
      assert_equal 3, @list.member_count
    end

    def test_owner
      assert_equal 9, @list.owner_id
      assert_equal "sferik", @list.owner.username
    end

    def test_private
      assert @list.private
      assert_predicate @list, :private?
      refute_predicate List.new({"id" => "1"}), :private?
    end

    def test_cursor_paths
      assert_equal "lists/1/members", @list.members.__send__(:path)
      assert_equal "lists/1/followers", @list.followers.__send__(:path)
      assert_equal "lists/1/tweets", @list.posts.__send__(:path)
      assert_equal "lists/1/tweets", @list.tweets.__send__(:path)
    end

    def test_cursor_classes
      assert_equal User, @list.members.resource_class
      assert_equal User, @list.followers.resource_class
      assert_equal Post, @list.posts.resource_class
      assert_same @client, @list.members.client
    end

    def test_cursor_max_results
      assert_equal 100, @list.members.__send__(:params)["max_results"]
      assert_equal 100, @list.followers.__send__(:params)["max_results"]
      assert_equal 100, @list.posts.__send__(:params)["max_results"]
    end

    def test_cursor_params
      assert_equal 5, @list.members(max_results: 5).__send__(:params)["max_results"]
      assert_equal 5, @list.followers(max_results: 5).__send__(:params)["max_results"]
      assert_equal 5, @list.posts(max_results: 5).__send__(:params)["max_results"]
    end

    def test_offers_no_batch_lookup
      refute_respond_to List, :find_all
      refute_respond_to List, :hydrate_all
    end

    def test_find
      @client.stub(:get, "lists/1", {"data" => {"id" => "1", "name" => "Ruby"}})

      assert_equal "Ruby", List.find(1, client: @client).name
      assert_equal List::FIELDS.join(","), @client.queries.first["list.fields"]
    end
  end
end
