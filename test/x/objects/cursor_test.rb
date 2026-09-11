require_relative "../../test_helper"

module X
  class CursorTest < Minitest::Test
    cover Cursor

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/followers", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "1"}, {"id" => "2"}], "meta" => {"next_token" => "p2", "result_count" => 2}}
        when "p2" then {"data" => [{"id" => "3"}], "meta" => {"next_token" => "p3", "result_count" => 1}}
        when "p3" then {"data" => [{"id" => "4"}], "meta" => {"result_count" => 1}}
        end
      })
      @cursor = Cursor.new(User, client: @client, path: "users/1/followers", params: {max_results: 1000})
    end

    def test_readers
      assert_equal User, @cursor.klass
      assert_same @client, @cursor.client
      assert_equal "users/1/followers", @cursor.path
      refute_predicate @cursor, :prefetch?
      assert_predicate @cursor, :frozen?
    end

    def test_params_merge_defaults
      assert_equal 1000, @cursor.params["max_results"]
      assert_equal User::FIELDS.join(","), @cursor.params["user.fields"]
      assert_equal Post::FIELDS.join(","), @cursor.params["tweet.fields"]
      assert_predicate @cursor.params, :frozen?
    end

    def test_params_default_to_resource_defaults
      cursor = Cursor.new(User, client: @client, path: "users/1/followers")

      assert_equal Objects::Utils.query(User.default_params), cursor.params
    end

    def test_params_override_defaults
      cursor = Cursor.new(User, client: @client, path: "users/1/followers", params: {"user.fields": "id", expansions: nil})

      assert_equal "id", cursor.params["user.fields"]
      refute cursor.params.key?("expansions")
    end

    def test_each_iterates_every_page
      assert_equal %w[1 2 3 4], @cursor.map(&:id)
      assert_equal [nil, "p2", "p3"], @client.queries.map { |query| query["pagination_token"] }
      assert_equal %w[1000 1000 1000], @client.queries.map { |query| query["max_results"] }
    end

    def test_each_returns_self
      assert_same @cursor, @cursor.each { |_user| nil }
    end

    def test_each_without_block
      enumerator = @cursor.each

      assert_kind_of Enumerator, enumerator
      assert_equal 4, enumerator.count
      assert_equal "1", @cursor.each.next.id
    end

    def test_each_is_lazy
      assert_equal %w[1 2], @cursor.first(2).map(&:id)
      assert_equal 1, @client.requests.size
    end

    def test_each_caches_pages
      2.times { @cursor.to_a }

      assert_equal 3, @client.requests.size
    end

    def test_each_page
      pages = @cursor.each_page.to_a

      assert_equal [2, 1, 1], pages.map(&:result_count)
      assert_equal %w[1 2], pages.first.map(&:id)
      assert_equal 3, @client.requests.size
    end

    def test_each_page_returns_self
      assert_same @cursor, @cursor.each_page { |_page| nil }
    end

    def test_each_page_without_block
      assert_kind_of Enumerator, @cursor.each_page
      assert_empty @client.requests
    end

    def test_concurrent_iteration_fetches_each_page_once
      results = Array.new(4) { Thread.new { @cursor.map(&:id) } }.map(&:value)

      assert_equal [%w[1 2 3 4]] * 4, results
      assert_equal 3, @client.requests.size
    end

    def test_concurrent_page_requests_fetch_once
      @client.stub(:get, "users/1/followers", lambda { |_, _|
        sleep 0.02
        {"data" => [{"id" => "1"}]}
      })
      pages = Array.new(4) { Thread.new { @cursor.page(0) } }.map(&:value)

      assert_equal 1, pages.uniq(&:object_id).size
      assert_equal 1, @client.requests.size
    end

    def test_inspect
      assert_equal '#<X::Cursor klass=X::User path="users/1/followers">', @cursor.inspect
    end
  end
end
