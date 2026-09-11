require "ostruct"
require_relative "../test_helper"

module X
  class IntegrationTest < Minitest::Test
    BASE = "https://api.twitter.com/2/".freeze

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_client_includes_objects_api
      assert_includes Client.ancestors, Objects::API
    end

    def test_user_by_username
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik", pinned_tweet_id: "1"},
                                                   includes: {tweets: [{id: "1", text: "pinned"}]}})
      user = @client.find_user("sferik")

      assert_equal "sferik", user.username
      assert_equal "pinned", user.pinned_post.text
      assert_same @client, user.client
    end

    def test_objects_ignore_default_object_class
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct, default_array_class: Set)
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})

      assert_equal "sferik", client.find_user("sferik").username
      assert_kind_of OpenStruct, client.get("users/by/username/sferik")
    end

    def test_hydrate_memoizes_across_requests
      stub_json(:get, "tweets/1", {data: {id: "1", author_id: "7505382"}})
      stub_json(:get, "users/7505382", {data: {id: "7505382", name: "Erik Berlin"}})
      author = @client.find_post(1).author
      2.times { author.hydrate }

      assert_equal "Erik Berlin", author.hydrate.name
      assert_requested :get, %r{users/7505382}, times: 1
    end

    def test_equality_across_requests
      stub_json(:get, "tweets/1", {data: {id: "1", author_id: "7505382"}})
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})

      assert_equal @client.find_user("sferik"), @client.find_post(1).author
    end

    def test_followers_paginate_with_maximum_page_size
      stub_page("users/7505382/followers", nil, %w[1 2], "p2")
      stub_page("users/7505382/followers", "p2", %w[3], nil)
      followers = User.new({"id" => "7505382"}, client: @client).followers

      assert_equal %w[1 2 3], followers.map(&:id)
      assert_equal %w[1 2 3], followers.map(&:id)
      assert_requested :get, %r{users/7505382/followers.*max_results=1000}, times: 2
    end

    private

    def stub_json(method, path, body)
      stub_request(method, /\A#{Regexp.escape(BASE + path)}(\?.*)?\z/)
        .to_return(body: JSON.generate(body), headers: {"content-type" => "application/json"})
    end

    def stub_page(path, token, ids, next_token)
      body = {data: ids.map { |id| {id:} }, meta: {next_token:}.compact}
      stub_request(:get, /\A#{Regexp.escape(BASE + path)}\?/)
        .with { |request| URI.decode_www_form(request.uri.query).to_h["pagination_token"].eql?(token) }
        .to_return(body: JSON.generate(body), headers: {"content-type" => "application/json"})
    end
  end
end
