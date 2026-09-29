# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class BookmarkFoldersTest < Minitest::Test
    cover BookmarkFolder
    cover Objects::UserCollections
    cover Cursor
    cover Objects::Pages
    cover Resource

    FOLDERS = {"data" => [{"id" => "1146654567674912769", "name" => "Ruby"}, {"id" => "2", "name" => "Rails"}], "meta" => {"result_count" => 2}}.freeze

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1/bookmarks/folders", FOLDERS)
      @client.stub(:get, "users/1/bookmarks/folders/1146654567674912769", {"data" => [{"id" => "10"}, {"id" => "11"}], "meta" => {"result_count" => 2}})
      @client.stub(:get, "tweets", ->(query, _) { {"data" => query["ids"].split(",").map { |id| {"id" => id, "text" => "post #{id}"} }} })
      @user = User.new({"id" => "1"}, client: @client)
    end

    def test_the_folders_of_a_user
      folders = @user.bookmark_folders.to_a

      assert_equal [[1_146_654_567_674_912_769, "Ruby"], [2, "Rails"]], folders.map { |folder| [folder.id, folder.name] }
      assert_equal [{"max_results" => "100"}], @client.queries
      assert_equal [true, true], folders.map(&:hydrated?)
      assert_same folders.first, folders.first.hydrate
    end

    def test_the_folders_page_with_the_pagination_token
      @client.stub(:get, "users/1/bookmarks/folders", lambda { |query, _|
        query["pagination_token"] ? {"data" => [{"id" => "2", "name" => "Rails"}]} : {"data" => [{"id" => "1", "name" => "Ruby"}], "meta" => {"next_token" => "p2"}}
      })

      assert_equal %w[Ruby Rails], @user.bookmark_folders(max_results: 1).map(&:name)
      assert_equal [[nil, "1"], %w[p2 1]], @client.queries.map { |query| query.values_at("pagination_token", "max_results") }
    end

    def test_the_posts_of_a_folder_ask_for_no_fields
      posts = @user.bookmarks(folder: "1146654567674912769").to_a

      assert_equal [10, 11], posts.map(&:id)
      assert_equal [{"max_results" => "100"}], @client.queries
      assert(posts.all?(&:stub?))
      refute(posts.any?(&:hydrated?))
    end

    def test_the_posts_of_a_folder_hydrate_together
      posts = @user.bookmarks(folder: @user.bookmark_folders.first).to_a

      assert_equal ["post 10", "post 11"], posts.map { |post| post.hydrate.text }
      assert_equal ["users/1/bookmarks/folders", "users/1/bookmarks/folders/1146654567674912769", "tweets"], @client.paths
      assert_equal "10,11", @client.queries.last["ids"]
    end

    def test_the_cursors_derived_from_the_posts_of_a_folder_ask_for_no_fields_either
      cursor = @user.bookmarks(folder: 1_146_654_567_674_912_769, max_results: 5)

      assert_equal [[10, 11], [10, 11]], [cursor.ids, cursor.refresh.prefetch.map(&:id)]
      assert_equal [{"max_results" => "5"}], @client.queries.uniq
      assert_equal [{"max_results" => 5}], [cursor.stubs.params]
    end

    def test_the_cursors_derived_from_the_posts_of_a_folder_hydrate_together
      cursor = @user.bookmarks(folder: 1_146_654_567_674_912_769)
      texts = %i[refresh prefetch stubs].map { |derived| cursor.public_send(derived).first(2).map { |post| post.hydrate.text } }

      assert_equal [["post 10", "post 11"]] * 3, texts
      assert_equal ["10,11"] * 3, @client.queries.filter_map { |query| query["ids"] }
    end

    def test_the_cursors_derived_from_every_bookmark_ask_for_every_field
      @client.stub(:get, "users/1/bookmarks", {"data" => [{"id" => "10", "text" => "hi"}]})
      cursor = @user.bookmarks

      assert_equal [Post::FIELDS.join(",")] * 3, [cursor, cursor.refresh, cursor.prefetch].map { |derived| derived.params["post.fields"] }
      assert_equal %w[hi hi], [cursor.refresh, cursor.prefetch].map { |derived| derived.first.text }
    end

    def test_a_cursor_that_asks_for_identifiers_alone_reads_stubs_that_hydrate_together
      @client.stub(:get, "users/1/liked_tweets", {"data" => [{"id" => "10"}, {"id" => "11"}]})
      posts = Cursor.__send__(:build, Post, "users/1/liked_tweets", client: @client, params: {"post.fields" => "id"}).to_a

      assert_equal ["post 10", "post 11"], posts.map { |post| post.hydrate.text }
      assert_equal ["users/1/liked_tweets", "tweets"], @client.paths
    end

    def test_the_posts_of_a_folder_take_parameters
      @user.bookmarks(folder: BookmarkFolder.from_id(1_146_654_567_674_912_769), "post.fields": "text").first

      assert_equal [{"max_results" => "1", "post.fields" => "text"}], @client.queries
    end

    def test_a_folder_that_is_not_one_is_refused_before_a_request
      assert_raises(ArgumentError) { @user.bookmarks(folder: "Ruby") }
      assert_raises(ArgumentError) { @user.bookmarks(folder: Post.from_id(1)) }
      assert_empty @client.requests
    end

    def test_the_bookmarks_without_a_folder_ask_for_every_field
      @client.stub(:get, "users/1/bookmarks", {"data" => [{"id" => "10", "text" => "hi"}]})
      post = @user.bookmarks.first

      assert_equal "hi", post.text
      assert_equal Post::FIELDS.join(","), @client.queries.first["post.fields"]
    end

    def test_a_folder_that_is_not_hydrated_cannot_be_looked_up
      folder = BookmarkFolder.from_id(2, client: @client)

      assert_nil folder.name
      assert_raises(UnsupportedOperation) { folder.hydrate }
      assert_empty BookmarkFolder.default_params
    end
  end
end
