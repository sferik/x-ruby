require_relative "../../test_helper"

module X
  class NameValidationTest < Minitest::Test
    cover Objects::Utils
    cover Objects::UserFinders
    cover Objects::API::Lookups
    cover Objects::Finders

    RAW_MESSAGE = "\"a/b?c=d\" is not an identifier: pass a resource, or a String of word characters".freeze

    def setup
      @client = FakeClient.new
    end

    def test_a_username_is_normalized
      assert_equal %w[sferik sferik _1 abcdefghijklmno], ["@sferik", "sferik", "_1", "abcdefghijklmno"].map { |name| Objects::Utils.username!(name) }
    end

    def test_a_username_that_is_no_string_is_read_as_one
      assert_equal "1", Objects::Utils.username!(1)
      assert_raises(ArgumentError) { Objects::Utils.username!(nil) }
    end

    def test_a_username_of_sixteen_characters_is_refused
      assert_raises(ArgumentError) { Objects::Utils.username!("abcdefghijklmnop") }
      assert_raises(ArgumentError) { Objects::Utils.username!("@@sferik") }
    end

    def test_what_is_not_a_username_is_refused
      error = assert_raises(ArgumentError) { Objects::Utils.username!("bad name") }

      assert_equal "\"bad name\" is not a username: pass one to fifteen letters, digits, or underscores", error.message
    end

    def test_find_user_refuses_a_path_traversal
      assert_raises(ArgumentError) { @client.find_user("../tweets/20") }
      assert_empty @client.requests
    end

    def test_find_user_refuses_an_empty_username
      assert_raises(ArgumentError) { @client.find_user("") }
      assert_empty @client.requests
    end

    def test_find_user_refuses_a_username_that_carries_a_query
      assert_raises(ArgumentError) { @client.find_user("a?expansions=x") }
      assert_empty @client.requests
    end

    def test_find_user_refuses_a_username_with_a_space
      assert_raises(ArgumentError) { @client.find_user("bad name") }
      assert_empty @client.requests
    end

    def test_find_users_refuses_a_username_that_is_not_one
      assert_raises(ArgumentError) { @client.find_users(["a?expansions=x"]) }
      assert_raises(ArgumentError) { User.find_all_by_username(["bad name"], client: @client) }
      assert_empty @client.requests
    end

    def test_find_user_still_looks_a_username_up
      @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "7505382", "username" => "sferik"}})

      assert_equal "sferik", @client.find_user("@sferik").username
      assert_equal ["users/by/username/sferik"], @client.paths
    end

    def test_find_space_refuses_an_identifier_that_is_not_word_characters
      assert_equal RAW_MESSAGE, assert_raises(ArgumentError) { @client.find_space("a/b?c=d") }.message
      assert_raises(ArgumentError) { @client.find_space("") }
      assert_empty @client.requests
    end

    def test_find_spaces_and_from_id_refuse_an_identifier_that_is_not_word_characters
      assert_raises(ArgumentError) { @client.find_spaces(["a b"]) }
      assert_raises(ArgumentError) { Space.from_id("a/b") }
      assert_empty @client.requests
    end

    def test_a_raw_identifier_of_word_characters_is_taken_as_it_is
      assert_equal %w[1DXxyRYNejbKM 3_1880028106020515840 f29bbd03562e37d3 a], %w[1DXxyRYNejbKM 3_1880028106020515840 f29bbd03562e37d3 a].map { |id| Objects::Utils.id_of(id, raw: true) }
    end

    def test_a_one_to_one_conversation_identifier_is_taken_as_it_is
      assert_equal "1-2", Objects::Utils.id_of("1-2", raw: true)
      assert_raises(ArgumentError) { Objects::Utils.id_of("a-2", raw: true) }
    end

    def test_find_by_username_looks_a_number_up_as_a_username
      @client.stub(:get, "users/by/username/1234567890", {"data" => {"id" => "9", "username" => "1234567890"}})

      assert_equal 9, @client.find_user_by_username("1234567890").id
      assert_equal 9, User.find_by_username("@1234567890", client: @client).id
      assert_equal ["users/by/username/1234567890"] * 2, @client.paths
    end

    def test_find_by_username_returns_nil_when_the_user_is_not_found
      @client.stub(:get, "users/by/username/nobody", {"errors" => [{"title" => "Not Found Error"}]})
      yielded = []

      assert_nil @client.find_user_by_username("nobody") { |problem| yielded << problem.title }
      assert_equal ["Not Found Error"], yielded
    end

    def test_find_by_username_bang_raises_when_the_user_is_not_found
      @client.stub(:get, "users/by/username/nobody", {"errors" => [{"title" => "Not Found Error", "detail" => "Could not find user."}]})

      error = assert_raises(MissingResource) { @client.find_user_by_username!("@nobody") }

      assert_equal "Could not find X::User @nobody: Could not find user.", error.message
      assert_equal ["Not Found Error"], error.problems.map(&:title)
    end

    def test_find_by_username_bang_returns_the_user
      @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "7505382", "username" => "sferik"}})

      assert_equal "sferik", @client.find_user_by_username!("sferik").username
      assert_equal "sferik", User.find_by_username!("sferik", client: @client).username
    end

    def test_find_by_username_refuses_what_is_not_a_username
      assert_raises(ArgumentError) { @client.find_user_by_username("a/b") }
      assert_raises(ArgumentError) { @client.find_user_by_username!("a/b") }
      assert_empty @client.requests
    end

    def test_find_by_username_merges_params
      @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "7505382"}})
      @client.find_user_by_username("sferik", "user.fields": "id")
      @client.find_user_by_username!("sferik", "user.fields": "name")

      assert_equal %w[id name], @client.queries.map { |query| query["user.fields"] }
    end
  end
end
