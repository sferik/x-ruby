# frozen_string_literal: true

require "yaml"
require_relative "../../test_helper"
require_relative "serialization_test"

module X
  # YAML writes a resource and a page as the plain data Marshal writes, without a client, and refuses a cursor
  class YAMLTest < Minitest::Test
    cover Resources.const_get(:Marshalling)
    cover Page
    cover Cursor

    def setup
      @client = SerializationTest::CredentialedClient.new
      includes = Resources.const_get(:Includes).new({"users" => [{"id" => "9", "username" => "sferik"}]})
      @post = Post.__send__(:build, {"id" => "1", "text" => "Hello", "author_id" => "9"}, client: @client, includes:)
    end

    def test_a_resource_is_written_without_its_client
      yaml = YAML.dump(@post)

      refute_includes yaml, "s3cr3t"
      refute_includes yaml, "9-token"
      refute_includes yaml, "client"
    end

    def test_a_resource_is_written_as_the_state_marshal_writes_under_its_names
      assert_equal({"format" => 1, "attrs" => @post.attrs, "hydrated" => false, "includes" => {"users" => [{"id" => "9", "username" => "sferik"}]},
                     "problems" => [], "query" => nil}, YAML.unsafe_load(YAML.dump(@post).sub("!ruby/object:X::Post", "")))
    end

    def test_a_resource_round_trips_without_its_client
      loaded = YAML.unsafe_load(YAML.dump(@post))

      assert_equal [@post, "Hello", "sferik", nil], [loaded, loaded.text, loaded.author.username, loaded.client]
      assert_equal @post.marshal_dump, loaded.marshal_dump
      assert_predicate loaded, :frozen?
    end

    def test_a_hydrated_resource_stays_hydrated
      post = Post.__send__(:build, {"id" => "1"}, client: @client, hydrated: true)

      assert_predicate YAML.unsafe_load(YAML.dump(post)), :hydrated?
    end

    def test_a_resource_within_what_is_written_is_written_without_its_client
      yaml = YAML.dump({"posts" => [@post]})

      refute_includes yaml, "s3cr3t"
      assert_equal "Hello", YAML.unsafe_load(yaml).fetch("posts").first.text
    end

    def test_a_resource_a_later_release_added_to_reads_back_as_it_was
      loaded = YAML.unsafe_load("#{YAML.dump(@post)}added: true\n")

      assert_equal [@post, "sferik"], [loaded, loaded.author.username]
    end

    def test_a_resource_of_another_format_raises
      yaml = YAML.dump(@post).sub("format: 1", "format: 2")

      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load(yaml) }
      assert_equal "X::Post reads format 1 of Marshal, not 2", error.message
    end

    def test_a_resource_of_another_format_that_names_other_parts_raises_for_the_format
      yaml = "--- !ruby/object:X::Post\nformat: 2\nattributes:\n  id: '1'\n"

      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load(yaml) }
      assert_equal "X::Post reads format 1 of Marshal, not 2", error.message
    end

    def test_a_page_is_written_without_the_clients_of_its_resources
      page = Page.new([@post], meta: {"result_count" => 1, "next_token" => "p2"}, problems: [Problem.new({"title" => "Not Found Error", "resource_id" => "8"})])
      yaml = YAML.dump(page)
      loaded = YAML.unsafe_load(yaml)

      refute_includes yaml, "s3cr3t"
      assert_equal [[@post], "p2", ["8"], "sferik", nil], [loaded.items, loaded.next_token, loaded.problems.map(&:resource_id), loaded.first.author.username, loaded.first.client]
      assert_predicate loaded, :frozen?
    end

    def test_a_page_is_written_as_the_state_marshal_writes_under_its_names
      page = Page.new([@post], meta: {"result_count" => 1})

      assert_equal %w[format resources meta problems includes], YAML.unsafe_load(YAML.dump(page).sub("!ruby/object:X::Page", "")).keys
    end

    def test_a_page_a_later_release_added_to_reads_back_as_it_was
      page = Page.new([@post], meta: {"result_count" => 1})

      assert_equal page, YAML.unsafe_load("#{YAML.dump(page)}added: true\n")
    end

    def test_a_page_of_another_format_raises
      yaml = YAML.dump(Page.new([@post])).sub("format: 1", "format: 2")

      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load(yaml) }
      assert_equal "X::Page reads format 1 of Marshal, not 2", error.message
    end

    def test_a_page_of_another_format_that_names_other_parts_raises_for_the_format
      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load("--- !ruby/object:X::Page\nformat: 2\n") }

      assert_equal "X::Page reads format 1 of Marshal, not 2", error.message
    end

    def test_a_cursor_refuses_yaml
      @client.stub(:get, "users/9/followers", {"data" => [{"id" => "1"}], "meta" => {}})
      cursor = User.from_id(9, client: @client).followers

      error = assert_raises(TypeError) { YAML.dump(cursor) }
      assert_equal "Serializing a cursor would read every page of its collection, a billed request per page; " \
        "serialize cursor.first(n), or cursor.to_a to read every page", error.message
      assert_raises(TypeError) { YAML.dump({"followers" => cursor}) }
      assert_empty @client.requests
    end
  end
end
