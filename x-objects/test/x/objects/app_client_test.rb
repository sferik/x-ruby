# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AppClientTest < Minitest::Test
    cover Objects.const_get(:Utils)
    cover Objects.const_get(:PostCounts)
    cover PostUsage

    # A client with an app-only client, as an X::Client that signs with OAuth 1.0a has
    class UserClient < FakeClient
      attr_reader :app, :app_only_calls

      def initialize
        super
        @app = FakeClient.new
        @app_only_calls = 0
      end

      def app_only
        @app_only_calls += 1
        app
      end
    end

    def test_counts_and_usage_use_the_app_only_client
      client = UserClient.new
      client.app.stub(:get, "tweets/counts/recent", {"meta" => {"total_tweet_count" => 5, "next_token" => nil}})
      client.app.stub(:get, "usage/tweets", {"data" => {"project_usage" => "7"}})

      assert_equal [5, 7], [client.count_posts("ruby"), client.post_usage.project_usage]
      assert_equal [2, []], [client.app_only_calls, client.requests]
    end

    def test_a_count_of_many_pages_asks_for_the_app_only_client_once
      client = UserClient.new
      client.app.stub(:get, "tweets/counts/all", ->(query, _) { {"meta" => {"total_post_count" => 1, "next_token" => (query["next_token"] ? nil : "p2")}} })

      assert_equal 2, Post.count_all("ruby", client:)
      assert_equal 1, client.app_only_calls
    end

    def test_a_client_that_cannot_authenticate_as_the_app_counts_recent_posts_as_the_user
      client = FakeClient.new.stub(:get, "tweets/counts/recent", {"meta" => {"total_tweet_count" => 5}})
      def client.app_only = raise(UnsupportedOperation, "no app credentials")

      assert_equal [5, {}], [client.count_posts("ruby"), client.count_posts_by_period("ruby")]
      assert_equal ["tweets/counts/recent"] * 2, client.paths
    end

    def test_a_client_that_cannot_authenticate_as_the_app_cannot_count_the_full_archive
      client = FakeClient.new
      def client.app_only = raise(UnsupportedOperation, "no app credentials")

      assert_raises(UnsupportedOperation) { client.count_all_posts("ruby") }
      assert_empty client.paths
    end

    def test_a_client_without_an_app_only_client_is_used_as_it_is
      client = FakeClient.new.stub(:get, "usage/tweets", {"data" => {"project_cap" => "9"}})

      assert_equal 9, client.post_usage.project_cap
      assert_equal ["usage/tweets"], client.paths
    end

    def test_a_space_endpoint_takes_the_app_only_client_of_a_client_that_has_one
      client = UserClient.new

      assert_same client.app, Objects.const_get(:Utils).space_client(client)
    end

    def test_a_space_endpoint_takes_a_client_that_cannot_authenticate_as_the_app_as_it_is
      client = FakeClient.new
      def client.app_only = raise(UnsupportedOperation, "no app credentials")

      assert_same client, Objects.const_get(:Utils).space_client(client)
    end

    def test_a_space_endpoint_raises_any_other_error_of_the_app_only_client
      client = FakeClient.new
      def client.app_only = raise(Error, "refused")

      assert_raises(Error) { Objects.const_get(:Utils).space_client(client) }
    end
  end
end
