require_relative "../../test_helper"

module X
  class PostCountsTest < Minitest::Test
    cover Objects::PostCounts
    cover Objects::API::Lookups

    def setup
      @client = FakeClient.new
      @client.stub(:get, "tweets/counts/recent", lambda { |query, _|
        if query["next_token"]
          {"data" => [{"start" => "2026-09-14T00:00:00.000Z", "end" => "2026-09-15T00:00:00.000Z", "post_count" => 4}], "meta" => {"total_post_count" => 4}}
        else
          {"data" => [{"start" => "2026-09-15T00:00:00.000Z", "end" => "2026-09-16T00:00:00.000Z", "tweet_count" => 6}], "meta" => {"total_tweet_count" => 6, "next_token" => "p2"}}
        end
      })
    end

    def test_count_totals_every_page
      assert_equal 10, Post.count("ruby", client: @client)
      assert_equal [{"query" => "ruby", "granularity" => "day"}, {"query" => "ruby", "granularity" => "day", "next_token" => "p2"}], @client.queries
    end

    def test_counts_by_period
      counts = Post.counts("ruby", client: @client, granularity: "hour", start_time: "2026-09-14T00:00:00Z")

      assert_equal({Time.utc(2026, 9, 15) => 6, Time.utc(2026, 9, 14) => 4}, counts)
      assert_predicate counts, :frozen?
      assert_equal({"query" => "ruby", "granularity" => "hour", "start_time" => "2026-09-14T00:00:00Z"}, @client.queries.first)
    end

    def test_the_full_archive
      @client.stub(:get, "tweets/counts/all", {"data" => [{"start" => "2024-01-01T00:00:00.000Z", "tweet_count" => 3}], "meta" => {"total_tweet_count" => 3}})

      assert_equal 3, Post.count_all("ruby", client: @client)
      assert_equal({Time.utc(2024) => 3}, Post.counts_all("ruby", client: @client))
      assert_equal ["tweets/counts/all"] * 2, @client.paths
    end

    def test_a_response_without_counts
      @client.stub(:get, "tweets/counts/all", {"errors" => []})

      assert_equal 0, Post.count_all("ruby", client: @client)
      assert_empty Post.counts_all("ruby", client: @client)
    end

    def test_an_empty_response
      @client.stub(:get, "tweets/counts/all", nil)

      assert_equal 0, Post.count_all("ruby", client: @client)
    end

    def test_client_methods_pass_the_query_and_parameters
      @client.stub(:get, "tweets/counts/all", {"meta" => {"total_tweet_count" => 3}})
      %i[count_posts post_counts count_all_posts post_counts_all].each { |method| @client.public_send(method, "ruby", granularity: "hour") }

      assert_equal [{"query" => "ruby", "granularity" => "hour"}], @client.queries.reject { |query| query.key?("next_token") }.uniq
      assert_equal %w[tweets/counts/recent tweets/counts/all], @client.paths.uniq
    end

    def test_client_methods_and_tweet_aliases_for_recent_posts
      assert_equal [10, 10], [@client.count_posts("ruby"), @client.count_tweets("ruby")]
      assert_equal [6, 6], [@client.post_counts("ruby"), @client.tweet_counts("ruby")].map { |counts| counts[Time.utc(2026, 9, 15)] }
    end

    def test_client_methods_and_tweet_aliases_for_the_full_archive
      @client.stub(:get, "tweets/counts/all", {"data" => [{"start" => "2024-01-01T00:00:00.000Z", "tweet_count" => 3}], "meta" => {"total_tweet_count" => 3}})

      assert_equal [3, 3], [@client.count_all_posts("ruby"), @client.count_all_tweets("ruby")]
      assert_equal [{Time.utc(2024) => 3}] * 2, [@client.post_counts_all("ruby"), @client.tweet_counts_all("ruby")]
    end
  end
end
