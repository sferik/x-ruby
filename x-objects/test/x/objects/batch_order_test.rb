# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A batch lookup returns the resources in the order they were asked for, whatever order the API answers in
  class BatchOrderTest < Minitest::Test
    cover Objects.const_get(:Finders)
    cover Objects.const_get(:BatchFinders)
    cover Objects.const_get(:UserFinders)
    cover Media

    def setup
      @client = FakeClient.new
      %w[tweets spaces users].each { |path| @client.stub(:get, path, reversed("ids") { |id| {"id" => id} }) }
      @client.stub(:get, "media", reversed("media_keys") { |key| {"media_key" => key} })
      @client.stub(:get, "users/by", reversed("usernames") { |name| {"id" => name.ord.to_s, "username" => name} })
    end

    def test_posts_spaces_and_media_come_back_in_the_order_they_were_asked_for
      assert_equal [3, 1, 2], Post.find_all([3, "01", 2], client: @client).map(&:id)
      assert_equal %w[b a], Space.find_all(%w[b a], client: @client).map(&:id)
      assert_equal %w[3_2 3_1], Media.find_all(%w[3_2 3_1], client: @client).map(&:media_key)
    end

    def test_users_come_back_in_the_order_they_were_asked_for
      assert_equal [2, 1], User.find_all_by_id(%w[2 1], client: @client).map(&:id)
      assert_equal %w[b a], User.find_all_by_username(%w[B @a], client: @client).map(&:username)
    end

    def test_a_resource_asked_for_twice_comes_back_twice_but_is_asked_for_once
      assert_equal [2, 1, 2], Post.find_all([2, 1, "2"], client: @client).map(&:id)
      assert_equal %w[b a b], Space.find_all(%w[b a b], client: @client).map(&:id)
      assert_equal ["2,1", "b,a"], @client.queries.map { |query| query["ids"] }
    end

    def test_a_user_asked_for_twice_comes_back_twice_but_is_asked_for_once
      assert_equal [2, 1, 2], User.find_all_by_id([2, 1, 2], client: @client).map(&:id)
      assert_equal %w[b a b], User.find_all_by_username(%w[b a @B], client: @client).map(&:username)
      assert_equal %w[b b], User.find_all(%w[b @B], client: @client).map(&:username)
      assert_equal ["2,1", "b,a", "b"], @client.queries.map { |query| query["ids"] || query["usernames"] }
    end

    def test_find_all_keeps_what_was_asked_for_twice_as_hydrate_all_does
      post = Post.from_id(2, client: @client)
      found = Post.find_all([post, 3, post], client: @client)

      assert_equal found, Post.hydrate_all([post, Post.from_id(3), post], client: @client)
      assert_equal [2, 3, 2], found.map(&:id)
    end

    private

    # A lookup whose API answers with the values of a batch in reverse
    def reversed(key, &data) = ->(query, _) { {"data" => query[key].split(",").reverse.map(&data)} }
  end
end
