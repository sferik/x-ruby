require_relative "../../test_helper"

module X
  class CursorCountTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover Objects::Resource
    cover List
    cover Post
    cover User

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        {"data" => (1..query.fetch("max_results").to_i).map { |id| {"id" => id.to_s} }}
      })
      @user = User.new({"id" => "1", "public_metrics" => {"followers_count" => 12}}, client: @client)
    end

    def test_any_asks_for_one_resource
      assert_predicate @user.followers, :any?
      assert_equal %w[1], @client.queries.map { |query| query["max_results"] }
    end

    def test_any_with_a_block_or_a_pattern_scans_the_collection
      assert(@user.followers.any? { |follower| follower.id.eql?(2) })
      refute @user.followers.any?(Post)
      assert_equal %w[1000 1000], @client.queries.map { |query| query["max_results"] }
    end

    def test_none_asks_for_one_resource
      @client.stub(:get, "users/1/followers", {"data" => []})

      assert_predicate @user.followers, :none?
      refute_predicate @user.followers, :any?
      assert_equal %w[1 1], @client.queries.map { |query| query["max_results"] }
    end

    def test_none_with_a_block_or_a_pattern_scans_the_collection
      assert(@user.followers.none? { |follower| follower.id.eql?(0) })
      assert @user.followers.none?(Post)
      refute @user.followers.none?(User)
      assert_equal %w[1000 1000 1000], @client.queries.map { |query| query["max_results"] }
    end

    def test_one_asks_for_two_resources
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}]})

      assert_predicate @user.followers, :one?
      assert_equal %w[2], @client.queries.map { |query| query["max_results"] }
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})

      refute_predicate @user.followers, :one?
    end

    def test_one_with_a_block_or_a_pattern_scans_the_collection
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}]})

      assert(@user.followers.one? { |follower| follower.id.eql?(2) })
      assert @user.followers.one?(User)
      refute @user.followers.one?(Post)
      assert_equal %w[1000 1000 1000], @client.queries.map { |query| query["max_results"] }
    end

    def test_count_and_size_read_the_number_the_api_publishes
      assert_equal 12, @user.followers.count
      assert_equal 12, @user.followers.size
      assert_empty @client.requests
    end

    def test_count_of_a_collection_the_api_publishes_no_number_for
      @client.stub(:get, "users/1/muting", {"data" => [{"id" => "2"}, {"id" => "3"}]})

      assert_equal 2, @user.muting.count
      assert_equal 2, @user.muting.size
    end

    def test_count_falls_back_to_a_scan_without_the_metric
      user = User.new({"id" => "1"}, client: @client)

      assert_equal 1000, user.followers.count
    end

    def test_count_with_a_block_or_a_resource_counts_what_it_is_given
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})

      assert_equal 1, @user.followers.count { |follower| follower.id.eql?(2) }
      assert_equal 1, @user.followers.count(User.new({"id" => "2"}, client: @client))
    end

    def test_derived_cursors_keep_the_published_number
      assert_equal [12, 12, 12], [@user.followers.refresh, @user.followers.prefetch, @user.followers.stubs].map(&:count)
      assert_equal 12, @user.followers.send(:sized, 3).count
    end

    def test_the_collections_the_api_publishes_a_number_for
      list = List.new({"id" => "9", "member_count" => 3, "follower_count" => 4}, client: @client)
      user = User.new({"id" => "1", "public_metrics" => {"following_count" => 5, "listed_count" => 6}}, client: @client)

      assert_equal [3, 4, 5, 6], [list.members, list.followers, user.following, user.list_memberships].map(&:count)
    end
  end
end
