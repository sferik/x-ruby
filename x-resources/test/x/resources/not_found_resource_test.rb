# frozen_string_literal: true

require "x/core"
require_relative "../../test_helper"

module X
  # What is built on the lookup of one resource reads a 404 that reports the resource as not found as it reads a
  # response that holds no data: hydrate and refresh return nil, and a check that looks a user or a list up answers as
  # it does for one that was not found. Any other 404 raises NotFound, and nothing is remembered of it
  class NotFoundResourceTest < Minitest::Test
    cover Resource
    cover List
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:Relationships)

    BODY = '{"errors":[{"value":"1","detail":"Could not find tweet with id: [1].","title":"Not Found Error","resource_type":"tweet","parameter":"id",' \
      '"resource_id":"1","type":"https://api.twitter.com/2/problems/resource-not-found"}],"title":"Not Found Error",' \
      '"detail":"Could not find tweet with id: [1].","type":"https://api.twitter.com/2/problems/resource-not-found"}'
    JSON_HEADERS = {"content-type" => "application/json; charset=utf-8"}.freeze

    def setup
      @client = FakeClient.new
    end

    def test_hydrate_of_a_resource_the_api_answers_404_for_is_nil_and_remembered
      @client.stub(:get, "tweets/1", not_found("tweets/1"))
      post = Post.from_id(1, client: @client)

      assert_nil post.hydrate
      assert_nil post.hydrate
      assert_equal ["tweets/1"], @client.paths
    end

    def test_refresh_of_a_resource_the_api_answers_404_for_is_nil_and_remembered
      @client.stub(:get, "users/1", not_found("users/1"))
      user = User.new({"id" => "1", "username" => "sferik"}, client: @client, hydrated: true)

      assert_nil user.refresh
      assert_nil user.hydrate
      assert_equal ["users/1"], @client.paths
    end

    def test_refresh_of_a_resource_the_api_answers_a_bare_404_for_raises_not_found_and_keeps_what_it_held
      @client.stub(:get, "users/1", not_found("users/1", "", {}))
      user = User.new({"id" => "1", "username" => "sferik"}, client: @client, hydrated: true)

      assert_raises(NotFound) { user.refresh }
      assert_same user, user.hydrate
      assert_equal ["users/1"], @client.paths
    end

    def test_refresh_finds_a_resource_again_after_a_404_that_reported_it_as_not_found
      @client.stub(:get, "tweets/1", not_found("tweets/1"))
      post = Post.from_id(1, client: @client)

      assert_nil post.hydrate
      @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "back"}})

      assert_equal "back", post.refresh.text
      assert_equal "back", post.hydrate.text
    end

    def test_hydrate_and_refresh_raise_any_other_status_as_it_is
      @client.stub(:get, "tweets/1", ->(*) { raise Forbidden.new(status: 403, headers: JSON_HEADERS, body: BODY) })

      assert_raises(Forbidden) { Post.from_id(1, client: @client).hydrate }
      assert_raises(Forbidden) { Post.from_id(1, client: @client).refresh }
    end

    def test_follows_of_a_user_the_api_answers_404_for_is_false
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @client.stub(:get, "users/7", not_found("users/7"))

      refute User.new({"id" => "9"}, client: @client).follows?(7)
      refute User.new({"id" => "7"}, client: @client).follows?(9)
      assert_equal ["users/me", "users/7", "users/7"], @client.paths
    end

    def test_member_of_a_user_the_api_answers_404_for_scans_the_members_of_the_list
      @client.stub(:get, "users/2", not_found("users/2"))
      @client.stub(:get, "lists/9/members", {"data" => [{"id" => "3"}]})

      refute_operator List.new({"id" => "9", "private" => false, "member_count" => 5}, client: @client, hydrated: true), :member?, 2
      assert_equal ["users/2", "lists/9/members"], @client.paths
    end

    def test_member_of_a_list_the_api_answers_404_for_scans_its_members
      @client.stub(:get, "lists/9", not_found("lists/9"))
      @client.stub(:get, "lists/9/members", {"data" => [{"id" => "2"}]})

      assert_operator List.from_id(9, client: @client), :member?, 2
      assert_equal ["lists/9", "lists/9/members"], @client.paths
    end

    private

    # A response that raises the NotFound x-core raises for a 404 to the lookup of a path with the body, as X::Client does
    def not_found(path, body = BODY, headers = JSON_HEADERS)
      ->(*) { raise NotFound.new(status: 404, headers:, body:, http_method: "GET", uri: URI("https://api.x.com/2/#{path}?user.fields=id")) }
    end
  end
end
