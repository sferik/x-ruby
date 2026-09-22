# frozen_string_literal: true

require "ostruct"
require_relative "../test_helper"

module X
  class IntegrationTest < Minitest::Test
    BASE = "https://api.x.com/2/"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_require_x_loads_the_uploaders
      assert_respond_to Uploader::MediaUpload, :upload
      assert_respond_to Uploader::Account, :update_profile_image
    end

    def test_a_copy_with_other_credentials_authenticates_as_another_user
      stub_current_user(TEST_BEARER_TOKEN, "9")
      stub_current_user("OTHER", "12")

      assert_equal 9, @client.current_user!.id
      assert_equal 12, @client.with(bearer_token: "OTHER").current_user!.id
    end

    def test_client_includes_objects_api
      assert_includes Client.ancestors, Objects::API
    end

    def test_user_by_username
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik", pinned_post_id: "1"},
                                                   includes: {posts: [{id: "1", text: "pinned"}]}})
      user = @client.find_user("sferik")

      assert_equal "sferik", user.username
      assert_equal "pinned", user.pinned_post.text
      assert_same @client, user.client
    end

    def test_resource_class_as_object_class
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik", pinned_post_id: "1"},
                                                   includes: {posts: [{id: "1", text: "pinned"}]}})
      user = @client.get("users/by/username/sferik", object_class: User)

      assert_equal "sferik", user.username
      assert_equal "pinned", user.pinned_post.text
      assert_same @client, user.client
    end

    def test_resource_class_as_object_class_for_a_list
      stub_json(:get, "users/by", {data: [{id: "7505382", username: "sferik"}, {id: "1", username: "gem"}]})

      assert_equal %w[sferik gem], @client.get("users/by?usernames=sferik,gem", object_class: User).map(&:username)
    end

    def test_objects_ignore_the_default_classes
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, default_object_class: OpenStruct, default_array_class: Set)
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})

      assert_equal "sferik", client.find_user("sferik").username
      assert_equal "sferik", client.get("users/by/username/sferik", object_class: User).username
      assert_kind_of OpenStruct, client.get("users/by/username/sferik")
    end

    def test_a_requested_object_hydrates_to_the_full_resource
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})
      stub_json(:get, "users/7505382", {data: {id: "7505382", public_metrics: {followers_count: 12_345}}})
      user = @client.get("users/by/username/sferik", object_class: User)

      assert_nil user.followers_count
      assert_equal 12_345, user.hydrate.followers_count
      assert_requested :get, %r{users/7505382\?.*user\.fields=}, times: 1
    end

    def test_a_looked_up_object_is_already_hydrated
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})
      user = @client.find_user("sferik")

      assert_same user, user.hydrate
    end

    def test_hydrate_memoizes_across_requests
      stub_json(:get, "tweets/1", {data: {id: "1", author_id: "7505382"}})
      stub_json(:get, "users/7505382", {data: {id: "7505382", name: "Erik Berlin"}})
      author = @client.find_post(1).author
      2.times { author.hydrate }

      assert_equal "Erik Berlin", author.hydrate.name
      assert_requested :get, %r{users/7505382}, times: 1
    end

    def test_equality_across_requests_and_entry_points
      stub_json(:get, "tweets/1", {data: {id: "1", author_id: "7505382"}})
      stub_json(:get, "users/by/username/sferik", {data: {id: "7505382", username: "sferik"}})

      assert_equal @client.find_user("sferik"), @client.get("tweets/1", object_class: Post).author
    end

    def test_followers_paginate_with_maximum_page_size
      stub_page("users/7505382/followers", nil, %w[1 2], "p2")
      stub_page("users/7505382/followers", "p2", %w[3], nil)
      followers = User.new({"id" => "7505382"}, client: @client).followers

      assert_equal [1, 2, 3], followers.map(&:id)
      assert_equal [1, 2, 3], followers.map(&:id)
      assert_requested :get, %r{users/7505382/followers.*max_results=1000}, times: 2
    end

    def test_hide_a_reply
      stub_json(:put, "tweets/1/hidden", {data: {hidden: true}})

      assert @client.hide_reply(1)
      assert_requested :put, "#{BASE}tweets/1/hidden", body: {hidden: true}.to_json
    end

    private

    def stub_current_user(bearer_token, id)
      stub_request(:get, /users\/me/).with(headers: {"Authorization" => "Bearer #{bearer_token}"})
        .to_return(headers: {"content-type" => "application/json"}, body: {data: {id:}}.to_json)
    end

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

  class ConcurrencyTest < Minitest::Test
    def test_the_batches_of_a_lookup_and_the_chunks_of_an_upload_run_as_wide
      assert_equal Uploader::MediaUpload::DEFAULT_CONCURRENCY, Objects::Finders::DEFAULT_CONCURRENCY
    end
  end
end
