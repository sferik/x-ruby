# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The internals a resource or cursor is built with, which build takes and new keeps to itself
  class InternalConstructorsTest < Minitest::Test
    cover Resource
    cover Cursor
    cover Media

    def setup
      @client = FakeClient.new
      @includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
    end

    def test_new_takes_no_includes_or_batch
      assert_raises(ArgumentError) { Post.new({"id" => "1"}, includes: @includes) }
      assert_raises(ArgumentError) { User.new({"id" => "1"}, batch: nil) }
    end

    def test_new_builds_a_resource_that_is_hydrated_when_told_so
      user = User.new({"id" => "1"}, client: @client, hydrated: true)

      assert_equal [1, true, true], [user.id, user.hydrated?, user.frozen?]
    end

    def test_build_resolves_references_over_the_includes_it_is_given
      post = Post.__send__(:build, {"id" => "1", "author_id" => "9"}, client: @client, includes: @includes, hydrated: true)

      assert_equal ["sferik", true, true], [post.author.username, post.hydrated?, post.frozen?]
    end

    def test_from_id_takes_no_batch
      assert_raises(ArgumentError) { User.from_id(1, batch: nil) }
      assert_raises(ArgumentError) { Media.from_id("3_1", batch: nil) }
    end

    def test_from_id_in_batch_builds_a_stub_of_the_batch
      batch = Objects::Batch.new(User, [1], client: @client)
      stub = User.__send__(:from_id_in_batch, 1, client: @client, batch:)

      assert_equal [1, true, []], [stub.id, stub.stub?, stub.problems]
      assert_same batch, stub.instance_variable_get(:@batch)
    end

    def test_cursor_new_is_private
      assert_raises(NoMethodError) { Cursor.new(User, "users/1/followers", client: @client) }
      assert_raises(NoMethodError) { Cursor.build(User, "users/1/followers", client: @client) }
    end

    def test_cursor_build_pages_by_pagination_token_as_the_user_by_default
      cursor = Cursor.__send__(:build, User, "users/1/followers", client: @client)

      assert_equal [false, "pagination_token", 1, false, nil, false], [cursor.prefetch?, cursor.token_param, cursor.min_results, cursor.app_only?, cursor.published_count, cursor.__send__(:ids_only?)]
    end

    def test_cursor_build_keeps_the_options_it_is_given
      cursor = Cursor.__send__(:build, User, "users/search", client: @client, prefetch: true, token_param: "next_token", app_only: true)

      assert_equal [true, "next_token", true, nil], [cursor.prefetch?, cursor.token_param, cursor.app_only?, cursor.published_count]
    end

    def test_cursor_build_reads_the_total_it_is_given
      cursor = Cursor.__send__(:build, User, "users/1/followers", client: @client, params: {max_results: 5}, min_results: 2, app_only: false,
        total: ->(fresh: false) { fresh ? 2 : 1 })

      assert_equal [1, 2, true], [cursor.published_count, cursor.refresh.published_count, cursor.frozen?]
      assert_equal [User, "users/1/followers", @client, 2], [cursor.resource_class, cursor.path, cursor.client, cursor.min_results]
      assert_equal User::FIELDS.join(","), cursor.params["user.fields"]
    end
  end
end
