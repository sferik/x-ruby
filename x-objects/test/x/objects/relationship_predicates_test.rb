require_relative "../../test_helper"

module X
  class RelationshipPredicatesTest < Minitest::Test
    cover User
    cover X::Objects::UserFinders
    cover Objects::Relationships
    cover List
    cover Cursor

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/following", lambda { |query, _|
        case query["pagination_token"]
        when nil then {"data" => [{"id" => "2"}, {"id" => "3"}], "meta" => {"next_token" => "p2"}}
        when "p2" then {"data" => [{"id" => "4"}], "meta" => {}}
        end
      })
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_follows
      assert @user.follows?(3)
      assert @user.follows?("3")
      assert @user.follows?(User.new({"id" => "3"}))
      refute @user.follows?(5)
    end

    def test_follows_stops_at_the_first_match
      @user.follows?(2)

      assert_equal ["users/me", "users/1/following"], @client.paths
      assert_equal({"max_results" => "1000", "user.fields" => "id"}, @client.queries.last)
    end

    def test_follows_scans_every_page
      assert @user.follows?(4)
      assert_equal 3, @client.requests.size
    end

    def test_member
      @client.stub(:get, "lists/9/members", {"data" => [{"id" => "2"}]})
      list = List.new({"id" => "9", "private" => true, "member_count" => 1}, client: @client, hydrated: true)

      assert_operator list, :member?, 2
      assert_operator list, :member?, User.new({"id" => "2"})
      refute_operator list, :member?, "3"
      assert_equal({"max_results" => "100", "user.fields" => "id"}, @client.queries.first)
    end

    def test_stubs_configuration
      stubs = @user.following.stubs

      assert_kind_of Cursor, stubs
      assert_equal({"max_results" => 1000, "user.fields" => "id"}, stubs.params)
      assert_equal "users/1/following", stubs.path
      assert_equal "pagination_token", stubs.token_param
    end

    def test_stubs_yield_stubs
      stubs = @user.following.stubs

      assert(stubs.all?(&:stub?))
      assert_equal [2, 3, 4], stubs.map(&:id)
      assert_equal [2, 3, 4], @user.following.ids
    end

    def test_stubs_are_stubs_even_with_the_default_fields_of_the_api
      @client.stub(:get, "users/1/following", {"data" => [{"id" => "2", "name" => "Two", "username" => "two"}]})
      @client.stub(:get, "users/2", {"data" => {"id" => "2", "name" => "Two", "description" => "full"}})
      stub = @user.following.stubs.first

      assert_predicate stub, :stub?
      refute_predicate stub, :hydrated?
      assert_same @client, stub.client
      assert_equal "full", stub.hydrate.description
    end

    def test_a_cursor_with_fields_yields_hydrated_resources
      @client.stub(:get, "users/1/following", {"data" => [{"id" => "2", "name" => "Two"}]})
      user = @user.following("user.fields": "id,name").first

      assert_predicate user, :hydrated?
      assert_equal "Two", user.name
    end

    def test_a_cursor_without_a_fields_parameter_yields_hydrated_resources
      @client.stub(:get, "users/1/following", {"data" => [{"id" => "2", "name" => "Two"}]})
      user = @user.following("user.fields": nil).first

      assert_predicate user, :hydrated?
      refute_includes @client.queries.first, "user.fields"
    end

    def test_stubs_keep_the_token_param
      assert_equal "next_token", User.search("ruby", client: @client).stubs.token_param
    end
  end
end
