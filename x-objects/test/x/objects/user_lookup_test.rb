require_relative "../../test_helper"

module X
  class UserLookupTest < Minitest::Test
    cover User

    def setup
      @client = FakeClient.new
    end

    def test_find_by_id
      @client.stub(:get, "users/1", {"data" => {"id" => "1"}})

      assert_equal "1", User.find(1, client: @client).id
      assert_equal "1", User.find(User.new({"id" => "1"}), client: @client).id
    end

    def test_find_by_a_username_of_digits
      @client.stub(:get, "users/by/username/1", {"data" => {"id" => "2", "username" => "1"}})

      assert_equal "2", User.find("1", client: @client).id
    end

    def test_find_by_username
      @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "1", "username" => "sferik"}})
      user = User.find("sferik", client: @client, "user.fields": "id")

      assert_equal "sferik", user.username
      assert_predicate user, :hydrated?
      assert_equal "id", @client.queries.first["user.fields"]
      assert_equal User::EXPANSIONS.join(","), @client.queries.first["expansions"]
    end

    def test_find_all_by_id
      @client.stub(:get, "users", {"data" => [{"id" => "1"}, {"id" => "2"}]})

      assert_equal %w[1 2], User.find_all([1, 2], client: @client).map(&:id)
      assert_equal "1,2", @client.queries.first["ids"]
    end

    def test_find_all_by_username
      usernames = (1..101).map { |index| "user#{index}" }
      @client.stub(:get, "users/by", ->(query, _) { {"data" => query["usernames"].split(",").map { |name| {"id" => name, "username" => name} }} })

      assert_equal usernames, User.find_all(usernames, client: @client).map(&:username)
      assert_equal [usernames.first(100), ["user101"]], batches
    end

    def test_find_all_by_username_uses_threads
      threads = Queue.new
      @client.stub(:get, "users/by", ->(_, _) { threads << Thread.current && {"data" => []} })
      User.find_all((1..101).map { |index| "user#{index}" }, client: @client)

      assert_equal 2, threads.size
      refute_same Thread.current, threads.pop
    end

    def test_find_all_by_username_merges_params
      @client.stub(:get, "users/by", {"data" => []})
      User.find_all(["sferik"], client: @client, "user.fields": "id")

      assert_equal "id", @client.queries.first["user.fields"]
      assert_equal Post::FIELDS.join(","), @client.queries.first["tweet.fields"]
    end

    def test_find_all_mixed_uses_usernames
      @client.stub(:get, "users/by", {"data" => []})
      User.find_all([1, "sferik"], client: @client)

      assert_equal "1,sferik", @client.queries.first["usernames"]
    end

    def test_me
      @client.stub(:get, "users/me", {"data" => {"id" => "1", "username" => "sferik"}})
      me = User.me(client: @client, "user.fields": "id")

      assert_equal "sferik", me.username
      assert_predicate me, :hydrated?
      assert_equal "id", @client.queries.first["user.fields"]
      assert_equal User::EXPANSIONS.join(","), @client.queries.first["expansions"]
    end

    private

    def batches
      @client.queries.map { |query| query["usernames"].split(",") }.sort_by { |batch| -batch.size }
    end
  end
end
