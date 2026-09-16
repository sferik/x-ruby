require_relative "../../test_helper"

module X
  class CursorFirstTest < Minitest::Test
    cover Cursor
    cover Objects::Pages
    cover Community
    cover Post
    cover Objects::PostCollections
    cover User
    cover X::Objects::UserFinders
    cover Objects::Resource
    cover Objects::Finders

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        size = query.fetch("max_results", "3").to_i
        {"data" => (1..size).map { |id| {"id" => id.to_s} }, "meta" => {"next_token" => "p2"}.reject { query["pagination_token"] }}
      })
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_first_count_requests_a_page_of_that_size
      assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], @user.followers.first(10).map(&:id)
      assert_equal [{"max_results" => "10"}], @client.queries.map { |query| query.slice("max_results") }
      refute_predicate @user.followers.send(:sized, 10), :prefetch?
    end

    def test_take_requests_a_page_of_that_size
      assert_equal [1, 2, 3], @user.followers.take(3).map(&:id)
      assert_equal "3", @client.queries.first["max_results"]
      assert_empty @user.followers.take(0)
      assert_raises(TypeError) { @user.followers.take(nil) }
    end

    def test_first_without_a_count_requests_one_resource
      assert_equal 1, @user.followers.first.id
      assert_equal "1", @client.queries.first["max_results"]
    end

    def test_first_rises_to_the_minimum_of_the_endpoint
      @client.stub(:get, "users/1/tweets", {"data" => (1..5).map { |id| {"id" => id.to_s} }})

      assert_equal [1, 2], @user.posts.first(2).map(&:id)
      assert_equal "5", @client.queries.first["max_results"]
      assert_equal 5, @user.posts.min_results
    end

    def test_the_minimum_page_size_of_searches
      searches = [Post.search("ruby", client: @client), Post.search_all("ruby", client: @client), Community.search("ruby", client: @client)]

      assert_equal [10, 10, 10, 10], (searches + [Post.new({"id" => "2"}, client: @client).quotes]).map(&:min_results)
      assert_equal 1, User.search("ruby", client: @client).min_results
    end

    def test_the_minimum_page_size_of_timelines
      assert_equal [5, 5, 5], [@user.posts, @user.mentions, @user.liked_posts].map(&:min_results)
      assert_equal [1, 1, 1], [@user.followers, @user.home_timeline, Post.new({"id" => "2"}, client: @client).liked_by].map(&:min_results)
    end

    def test_first_of_the_page_size_uses_the_cursor_and_its_cache
      followers = @user.followers(max_results: 3)
      followers.first(3)
      followers.to_a

      assert_equal [{"max_results" => "3"}, {"max_results" => "3", "pagination_token" => "p2"}], @client.queries.map { |query| query.slice("max_results", "pagination_token") }
    end

    def test_first_of_a_cursor_without_a_page_size
      @client.stub(:get, "dm_events", {"data" => [{"id" => "1"}, {"id" => "2"}]})
      cursor = Cursor.new(DirectMessage, "dm_events", client: @client)

      assert_equal [1], cursor.first(1).map(&:id)
      refute_includes @client.queries.first, "max_results"
    end

    def test_first_with_a_negative_count_raises_without_a_request
      assert_raises(ArgumentError) { @user.followers.first(-1) }
      assert_empty @client.requests
    end

    def test_first_reads_a_page_size_given_as_a_string
      followers = @user.followers(max_results: "3")
      followers.first(3)
      followers.to_a

      assert_equal %w[3 3], @client.queries.map { |query| query["max_results"] }
    end

    def test_a_sized_cursor_keeps_the_settings_of_the_cursor
      cursor = Cursor.new(User, "users/1/followers", client: @client, params: {max_results: 1000, "user.fields": nil}, prefetch: true, token_param: "next_token", min_results: 2)
      sized = cursor.send(:sized, 1)

      assert_equal [User, "users/1/followers", true, "next_token", 2], [sized.klass, sized.path, sized.prefetch?, sized.token_param, sized.min_results]
      assert_equal({"max_results" => 2}, sized.params.slice("max_results", "user.fields"))
      assert_same @client, sized.client
    end

    def test_refresh_and_prefetch_keep_dropped_defaults
      cursor = @user.followers("user.fields": nil)

      refute_includes cursor.refresh.params, "user.fields"
      refute_includes cursor.prefetch.params, "user.fields"
      assert_predicate cursor.prefetch, :prefetch?
      refute_predicate cursor.refresh, :prefetch?
    end

    def test_derived_cursors_keep_the_minimum_page_size
      cursor = Cursor.new(User, "users/1/followers", client: @client, min_results: 7)

      assert_equal [7, 7, 7], [cursor.refresh, cursor.prefetch, cursor.stubs].map(&:min_results)
    end
  end
end
