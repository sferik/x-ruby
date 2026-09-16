require_relative "../../test_helper"

module X
  class CursorTokenTest < Minitest::Test
    cover Cursor

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/search", lambda { |query, _|
        case query["next_token"]
        when nil then {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "2"}], "meta" => {}}
        end
      })
      @cursor = Cursor.new(User, "users/search", client: @client, params: {query: "ruby"}, token_param: "next_token")
    end

    def test_default_token_param
      cursor = Cursor.new(User, "users/1/followers", client: @client)

      assert_equal "pagination_token", cursor.token_param
      assert_equal Cursor::DEFAULT_TOKEN_PARAM, cursor.token_param
    end

    def test_token_param
      assert_equal "next_token", @cursor.token_param
    end

    def test_pages_with_the_token_param
      assert_equal [1, 2], @cursor.map(&:id)
      assert_equal [nil, "p2"], @client.queries.map { |query| query["next_token"] }
      refute @client.queries.last.key?("pagination_token")
    end

    def test_refresh_keeps_the_token_param
      assert_equal "next_token", @cursor.refresh.token_param
    end

    def test_prefetch_keeps_the_token_param
      assert_equal "next_token", @cursor.prefetch.token_param
    end

    def test_ids
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}, {"id" => "2"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "3"}], "meta" => {}}
        end
      })
      cursor = Cursor.new(User, "users/1/followers", client: @client, params: {max_results: 1000})

      assert_equal [1, 2, 3], cursor.ids
      assert_equal [{"max_results" => "1000", "user.fields" => "id"}, {"max_results" => "1000", "user.fields" => "id", "pagination_token" => "p2"}], @client.queries
    end

    def test_ids_request_only_the_identifier_of_the_cursor_class
      @client.stub(:get, "tweets/1/liking_users", {"data" => [{"id" => "1"}]})
      @client.stub(:get, "users/1/tweets", {"data" => [{"id" => "1"}]})

      assert_equal [1], Cursor.new(User, "tweets/1/liking_users", client: @client).ids
      assert_equal [1], Cursor.new(Post, "users/1/tweets", client: @client).ids
      assert_equal [{"user.fields" => "id"}, {"post.fields" => "id"}], @client.queries
    end

    def test_ids_keep_the_token_param
      assert_equal [1, 2], @cursor.ids
      assert_equal [nil, "p2"], @client.queries.map { |query| query["next_token"] }
      assert_equal({"query" => "ruby", "user.fields" => "id"}, @client.queries.first)
    end

    def test_ids_without_a_fields_parameter
      error = assert_raises(NotImplementedError) { Cursor.new(Media, "media", client: @client).ids }

      assert_equal "X::Media has no fields parameter", error.message
      assert_empty @client.requests
    end

    def test_ids_do_not_use_the_cache
      @cursor.to_a
      @cursor.ids

      assert_equal 4, @client.requests.size
    end
  end
end
