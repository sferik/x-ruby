require_relative "../../test_helper"

module X
  class CommunityTest < Minitest::Test
    cover Community

    def setup
      @client = FakeClient.new
      @community = Community.new({"id" => "7", "name" => "Rubyists", "description" => "d", "created_at" => "2024-01-02T03:04:05.000Z",
                                  "member_count" => 3, "access" => "Public", "join_policy" => "Open"}, client: @client)
    end

    def test_class_configuration
      assert_equal "communities", Community.endpoint
      assert_nil Community.includes_key
      assert_equal "community.fields", Community.fields_key
      assert_equal({"community.fields" => Community::FIELDS}, Community.default_params)
    end

    def test_attributes
      assert_equal "Rubyists", @community.name
      assert_equal "d", @community.description
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @community.created_at
      assert_equal 3, @community.member_count
    end

    def test_access_and_join_policy
      assert_equal "Public", @community.access
      assert_equal "Open", @community.join_policy
    end

    def test_find
      @client.stub(:get, "communities/7", {"data" => {"id" => "7", "name" => "Rubyists"}})
      community = Community.find(7, client: @client)

      assert_equal "Rubyists", community.name
      assert_predicate community, :hydrated?
      assert_equal Community::FIELDS.join(","), @client.queries.first["community.fields"]
    end

    def test_hydrate
      @client.stub(:get, "communities/7", {"data" => {"id" => "7", "name" => "Rubyists"}})

      assert_equal "Rubyists", Community.from_id(7, client: @client).hydrate.name
    end

    def test_search
      cursor = Community.search("ruby", client: @client, max_results: 10)

      assert_equal "communities/search", cursor.path
      assert_equal ["ruby", 10, "next_token"], [cursor.params["query"], cursor.params["max_results"], cursor.token_param]
      assert_equal Community, cursor.klass
      assert_same @client, cursor.client
    end

    def test_search_defaults
      cursor = Community.search("ruby", client: @client)

      assert_equal 100, cursor.params["max_results"]
      assert_equal Community::FIELDS.join(","), cursor.params["community.fields"]
    end

    def test_search_pages_with_next_token
      @client.stub(:get, "communities/search", ->(query, _) { {"data" => [{"id" => query["next_token"].eql?("p2") ? "2" : "1"}], "meta" => {"next_token" => "p2"}.reject { query["next_token"] }} })

      assert_equal [1, 2], Community.search("ruby", client: @client).map(&:id)
    end

    def test_find_all_is_not_supported
      error = assert_raises(NotImplementedError) { Community.find_all([1, 2], client: @client) }

      assert_equal "X::Community cannot be fetched in batches; find 2 communities one at a time", error.message
      assert_empty @client.requests
    end
  end
end
