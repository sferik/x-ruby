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

    def test_count_and_size_read_every_page
      @client.stub(:get, "users/1/followers", {"data" => [{"id" => "2"}, {"id" => "3"}]})

      assert_equal [2, 2], [@user.followers.count, @user.followers.size]
      assert_equal %w[users/1/followers users/1/followers], @client.paths
    end

    def test_published_count_reads_the_number_the_api_publishes
      assert_equal 12, @user.followers.published_count
      assert_empty @client.requests
    end

    def test_published_count_of_a_collection_the_api_publishes_no_number_for
      assert_nil @user.muting.published_count
      assert_empty @client.requests
    end

    def test_published_count_of_a_stub_looks_up_the_number_the_api_publishes
      @client.stub(:get, "users/1", {"data" => {"id" => "1", "public_metrics" => {"followers_count" => 7}}})

      assert_equal 7, User.from_id(1, client: @client).followers.published_count
      assert_equal %w[users/1], @client.paths
    end

    def test_published_count_of_an_unhydrated_reference_looks_up_the_number_the_api_publishes
      @client.stub(:get, "users/1", {"data" => {"id" => "1", "public_metrics" => {"followers_count" => 7}}})

      assert_equal 7, User.new({"id" => "1", "username" => "sferik"}, client: @client).followers.published_count
      assert_equal %w[users/1], @client.paths
    end

    def test_published_count_is_nil_when_the_lookup_has_no_metric
      @client.stub(:get, "users/1", {"data" => {"id" => "1"}})

      assert_nil User.from_id(1, client: @client).followers.published_count
      assert_equal %w[users/1], @client.paths
    end

    def test_published_count_is_nil_when_the_resource_no_longer_exists
      @client.stub(:get, "users/1", {"errors" => [{"title" => "Not Found Error"}]})

      assert_nil User.from_id(1, client: @client).followers.published_count
    end

    def test_published_count_of_a_hydrated_resource_without_the_metric_is_nil_without_a_lookup
      assert_nil User.new({"id" => "1"}, client: @client, hydrated: true).followers.published_count
      assert_empty @client.requests
    end

    def test_derived_cursors_keep_the_published_number
      assert_equal [12, 12, 12], [@user.followers.refresh, @user.followers.prefetch, @user.followers.stubs].map(&:published_count)
      assert_equal 12, @user.followers.send(:sized, 3).published_count
    end

    def test_the_collections_the_api_publishes_a_number_for
      list = List.new({"id" => "9", "member_count" => 3, "follower_count" => 4}, client: @client)
      user = User.new({"id" => "1", "public_metrics" => {"following_count" => 5, "listed_count" => 6}}, client: @client)

      assert_equal [3, 4, 5, 6], [list.members, list.followers, user.following, user.list_memberships].map(&:published_count)
    end
  end
end
