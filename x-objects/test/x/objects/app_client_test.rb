require_relative "../../test_helper"

module X
  class AppClientTest < Minitest::Test
    cover Objects::Utils
    cover Objects::PostCounts
    cover Usage

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

      assert_equal [5, 7], [client.count_posts("ruby"), client.usage.project_usage]
      assert_equal [2, []], [client.app_only_calls, client.requests]
    end

    def test_a_count_of_many_pages_asks_for_the_app_only_client_once
      client = UserClient.new
      client.app.stub(:get, "tweets/counts/all", ->(query, _) { {"meta" => {"total_post_count" => 1, "next_token" => (query["next_token"] ? nil : "p2")}} })

      assert_equal 2, Post.count_all("ruby", client:)
      assert_equal 1, client.app_only_calls
    end

    def test_a_client_without_an_app_only_client_is_used_as_it_is
      client = FakeClient.new.stub(:get, "usage/tweets", {"data" => {"project_cap" => "9"}})

      assert_equal 9, client.usage.project_cap
      assert_equal ["usage/tweets"], client.paths
    end
  end
end
