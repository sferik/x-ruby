# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RepeatedTokenTest < Minitest::Test
    cover Cursor
    cover Objects.const_get(:Pages)
    cover Objects.const_get(:PostCounts)

    # An API that names the tokens of its pages in turn, from none for the first page
    def paging(path, tokens)
      FakeClient.new.stub(:get, path, lambda { |query, _|
        token = query["pagination_token"] || query["next_token"]
        index = token ? tokens.index(token).succ : 0
        {"data" => [{"id" => index.succ.to_s}], "meta" => {"next_token" => tokens[index]}.compact}
      })
    end

    def test_a_cursor_stops_at_a_page_that_names_its_own_token_as_the_next
      client = paging("users/1/followers", %w[a a])
      error = assert_raises(UnreadableResponse) { User.from_id(1, client:).followers.to_a }

      assert_equal 'Page 1 of users/1/followers names the next_token "a", which fetched an earlier page', error.message
      assert_equal [nil, "a"], client.queries.map { |query| query["pagination_token"] }
    end

    def test_a_cursor_stops_at_a_page_that_names_the_token_of_any_earlier_page
      client = paging("users/1/followers", %w[a b a])
      error = assert_raises(UnreadableResponse) { User.from_id(1, client:).followers.each_page.to_a }

      assert_equal 'Page 2 of users/1/followers names the next_token "a", which fetched an earlier page', error.message
      assert_equal 3, client.requests.size
    end

    def test_first_stops_at_a_repeated_token_as_well
      client = paging("users/1/followers", %w[a a])

      assert_raises(UnreadableResponse) { User.from_id(1, client:).followers.first(3) }
      assert_equal 2, client.requests.size
    end

    def test_a_repeated_token_is_no_invalid_attribute
      client = paging("users/1/followers", %w[a a])

      assert_instance_of UnreadableResponse, assert_raises(UnreadableResponse) { User.from_id(1, client:).followers.to_a }
      assert_instance_of UnreadableResponse, assert_raises(UnreadableResponse) { Post.count("ruby", client: paging("tweets/counts/recent", %w[a a])) }
    end

    def test_a_cursor_whose_tokens_differ_reads_every_page
      assert_equal [1, 2, 3], User.from_id(1, client: paging("users/1/followers", %w[a b])).followers.map(&:id)
    end

    def test_a_cursor_stops_at_a_first_page_that_names_the_token_it_was_given
      client = paging("users/1/followers", %w[a a])
      error = assert_raises(UnreadableResponse) { User.from_id(1, client:).followers(pagination_token: "a").to_a }

      assert_equal 'Page 0 of users/1/followers names the next_token "a", which fetched an earlier page', error.message
      assert_equal ["a"], client.queries.map { |query| query["pagination_token"] }
    end

    def test_a_count_stops_at_a_first_page_that_names_the_token_it_was_given
      client = paging("tweets/counts/recent", %w[a a])
      error = assert_raises(UnreadableResponse) { Post.count("ruby", client:, next_token: "a") }

      assert_equal 'The counts of X::Post name the next_token "a", which fetched an earlier page', error.message
      assert_equal ["a"], client.queries.map { |query| query["next_token"] }
    end

    def test_a_cursor_stops_at_a_page_that_names_an_empty_token
      client = paging("users/1/followers", ["a", ""])

      assert_equal [1, 2], User.from_id(1, client:).followers.map(&:id)
      assert_equal 2, client.requests.size
    end

    def test_a_count_stops_at_a_page_that_names_an_empty_token
      client = paging("tweets/counts/recent", ["a", ""])
      Post.count("ruby", client:)

      assert_equal [nil, "a"], client.queries.map { |query| query["next_token"] }
    end

    def test_a_cursor_given_a_token_reads_the_pages_after_it
      assert_equal [2, 3], User.from_id(1, client: paging("users/1/followers", %w[a b])).followers(pagination_token: "a").map(&:id)
    end

    def test_a_count_stops_at_a_page_that_names_the_token_of_an_earlier_page
      client = paging("tweets/counts/recent", %w[a b b])
      error = assert_raises(UnreadableResponse) { Post.count("ruby", client:) }

      assert_equal 'The counts of X::Post name the next_token "b", which fetched an earlier page', error.message
      assert_equal [nil, "a", "b"], client.queries.map { |query| query["next_token"] }
    end

    def test_a_count_whose_tokens_differ_reads_every_page
      client = paging("tweets/counts/recent", %w[a b])
      Post.count("ruby", client:)

      assert_equal [nil, "a", "b"], client.queries.map { |query| query["next_token"] }
    end
  end
end
