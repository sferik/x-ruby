# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A page is a Hash in the shape of its response, as a resource is a Hash of its attributes, and a cursor, which would
  # read every page to be one, refuses before it reads any, while each builds a Hash of the pairs a block returns
  class CollectionToHTest < Minitest::Test
    cover Page
    cover Cursor

    def setup
      @client = FakeClient.new
      @post = Post.new({"id" => "1", "text" => "Hello"})
    end

    def test_a_page_is_a_hash_in_the_shape_of_its_response
      page = Page.new([@post], meta: {"next_token" => "abc"})

      assert_equal page.as_json, page.to_h
      assert_predicate page.to_h, :frozen?
    end

    def test_a_page_builds_a_hash_of_the_pairs_a_block_returns
      assert_equal({1 => "Hello"}, Page.new([@post]).to_h { |post| [post.id, post.text] })
    end

    def test_a_cursor_refuses_to_be_a_hash_before_it_reads_a_page
      error = assert_raises(UnsupportedOperation) { paged_followers.to_h }

      assert_equal "Serializing a cursor would read every page of its collection, a billed request per page; " \
        "serialize cursor.first(n), or cursor.to_a to read every page", error.message
      assert_empty @client.requests
    end

    def test_a_cursor_builds_a_hash_of_the_pairs_a_block_returns_of_every_page
      assert_equal({1 => true, 2 => true}, paged_followers.to_h { |user| [user.id, true] })
    end

    private

    # A cursor over two pages of one follower each
    def paged_followers
      @client.stub(:get, "users/9/followers", ->(query, _) { {"data" => [{"id" => query["pagination_token"] ? "2" : "1"}], "meta" => {"next_token" => (query["pagination_token"] ? nil : "p2")}} })
      User.from_id(9, client: @client).followers
    end
  end
end
