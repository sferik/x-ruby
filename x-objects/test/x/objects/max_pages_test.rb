# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A scan or a count of the full archive reads no more pages than its max_pages, raising rather than answer from what
  # it read when the API names another page
  class MaxPagesTest < Minitest::Test
    cover Objects.const_get(:PageLimit)
    cover Objects.const_get(:Relationships)
    cover Objects.const_get(:PostCounts)
    cover List

    INVALID = "max_pages must be an Integer of at least 1, or nil for no limit, not %p"

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      stub_following
      stub_counts
      @user = User.new({"id" => "1"}, client: @client)
    end

    def stub_following
      @client.stub(:get, "users/1/following", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "2"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "3"}], "meta" => {"next_token" => "p3"}}
        when "p3" then {"data" => [{"id" => "4"}], "meta" => {}}
        end
      })
    end

    def stub_counts
      @client.stub(:get, "tweets/counts/all", lambda { |query, _|
        {"data" => [{"start" => "2024-01-01T00:00:00.000Z", "end" => "2024-01-02T00:00:00.000Z", "tweet_count" => 1}],
         "meta" => {"total_tweet_count" => 1, "next_token" => {nil => "p2", "p2" => "p3"}[query["next_token"]]}}
      })
    end

    def test_a_scan_answers_from_the_pages_its_limit_allows
      assert @user.follows?(3, max_pages: 2)
      assert @user.follows?(4, max_pages: 3)
      refute @user.follows?(5, max_pages: 3)
    end

    def test_a_scan_that_reaches_its_limit_with_pages_left_raises
      error = assert_raises(PageLimitReached) { @user.follows?(4, max_pages: 2) }

      assert_equal "User#follows? read the 2 pages max_pages allows, and the API names another", error.message
      assert_equal 3, @client.requests.size
    end

    def test_a_scan_without_a_limit_reads_every_page
      assert @user.follows?(4)
      assert @user.follows?(4, max_pages: nil)
    end

    def test_a_list_scans_its_members_up_to_its_limit
      @client.stub(:get, "lists/7/members", {"data" => [{"id" => "2"}], "meta" => {"next_token" => "m2"}})
      list = List.new({"id" => "7", "private" => true, "member_count" => 200}, client: @client, hydrated: true)

      member = list.member?(2, max_pages: 1)

      assert member
      error = assert_raises(PageLimitReached) { list.member?(3, max_pages: 1) }

      assert_equal "List#member? read the 1 pages max_pages allows, and the API names another", error.message
    end

    def test_a_list_scans_the_memberships_of_a_user_up_to_its_limit
      @client.stub(:get, "users/2/list_memberships", {"data" => [{"id" => "8"}], "meta" => {"next_token" => "l2"}})
      list = List.new({"id" => "7", "private" => false, "member_count" => 200}, client: @client, hydrated: true)
      user = User.new({"id" => "2", "public_metrics" => {"listed_count" => 1}}, client: @client, hydrated: true)

      error = assert_raises(PageLimitReached) { list.member?(user, max_pages: 1) }

      assert_equal "List#member? read the 1 pages max_pages allows, and the API names another", error.message
      assert_equal "users/2/list_memberships", @client.paths.last
    end

    def test_a_count_of_the_full_archive_requests_no_more_pages_than_its_limit
      assert_equal 3, Post.count_all("ruby", client: @client, max_pages: 3)
      error = assert_raises(PageLimitReached) { Post.count_all_by_period("ruby", client: @client, max_pages: 2) }

      assert_equal "The counts of X::Post read the 2 pages max_pages allows, and the API names another", error.message
      assert_equal 5, @client.requests.size
      refute_includes @client.queries.last, "max_pages"
    end

    def test_a_client_counts_the_full_archive_up_to_its_limit
      assert_raises(PageLimitReached) { @client.count_all_posts("ruby", max_pages: 1) }
      assert_raises(PageLimitReached) { @client.count_all_posts_by_period("ruby", max_pages: 1) }
    end

    def test_a_limit_that_is_not_a_count_of_pages_raises_before_a_request
      [0, -1, 1.0, "2", Float::INFINITY].each do |max_pages|
        [-> { @user.follows?(3, max_pages:) }, -> { List.from_id(7, client: @client).member?(2, max_pages:) },
          -> { Post.count_all("ruby", client: @client, max_pages:) }].each do |check|
          error = assert_raises(ArgumentError) { check.call }

          assert_equal format(INVALID, max_pages), error.message
        end
      end

      assert_empty @client.requests
    end
  end
end
