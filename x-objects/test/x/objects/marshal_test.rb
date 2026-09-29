# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "serialization_test"

module X
  # Marshal writes a resource as plain data, without its client, and reads it back as it was
  class MarshalTest < Minitest::Test
    cover Objects::Marshalling
    cover Objects::Includes

    def setup
      @client = SerializationTest::CredentialedClient.new
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
      @post = Post.__send__(:build, {"id" => "1", "text" => "Hello", "author_id" => "9"}, client: @client, includes:)
    end

    def test_marshal_round_trip
      loaded = Marshal.load(Marshal.dump(@post))

      assert_equal @post, loaded
      assert_equal "Hello", loaded.text
      assert_equal @post.attrs, loaded.attrs
    end

    def test_a_marshalled_resource_carries_no_client
      loaded = Marshal.load(Marshal.dump(@post))

      assert_nil loaded.client
      assert_raises(MissingClient) { loaded.hydrate }
      refute_predicate loaded, :hydrated?
      refute_includes Marshal.dump(@post), "s3cr3t"
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [1, @post.attrs, false, {"users" => [{"id" => "9", "username" => "sferik"}]}, [], nil], @post.marshal_dump
    end

    def test_a_marshalled_resource_resolves_the_references_its_response_included
      loaded = Marshal.load(Marshal.dump(@post))

      assert_equal "sferik", loaded.author.username
      assert_nil loaded.author.client
      assert_predicate loaded, :frozen?
    end

    def test_a_marshalled_resource_stays_hydrated
      query = User.default_params
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]}, query:)
      post = Post.__send__(:build, {"id" => "1", "author_id" => "9"}, client: @client, includes:, hydrated: true)
      loaded = Marshal.load(Marshal.dump(post))

      assert_predicate loaded, :hydrated?
      assert_same loaded, loaded.hydrate
      assert_equal post.marshal_dump, loaded.marshal_dump
    end

    def test_a_marshalled_resource_reports_the_problems_of_its_response
      problem = {"title" => "Not Found Error", "resource_id" => "9", "resource_type" => "user"}
      includes = Objects::Includes.new(nil, problems: [Problem.new(problem)])
      post = Post.__send__(:build, {"id" => "1", "author_id" => "9"}, client: @client, includes:)

      assert_equal [problem], Marshal.load(Marshal.dump(post)).problems.map(&:to_h)
    end

    def test_the_state_of_includes_is_plain_data
      query = {"user.fields" => "username"}
      includes = Objects::Includes.new({"users" => [{"id" => "9"}]}, problems: [Problem.new({"title" => "Gone"})], query:)

      assert_equal [{"users" => [{"id" => "9"}]}, [{"title" => "Gone"}], query], includes.state
    end

    def test_a_marshalled_resource_resolves_its_references_as_hydrated_as_they_were
      includes = Objects::Includes.new({"polls" => [{"id" => "5", "voting_status" => "open"}]}, query: Objects::Utils.query(Post.default_params))
      post = Post.__send__(:build, {"id" => "1", "attachments" => {"poll_ids" => ["5"]}}, client: @client, includes:)

      assert_predicate Marshal.load(Marshal.dump(post)).polls.first, :hydrated?
    end

    def test_a_resource_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { Post.allocate.marshal_load([2, {"id" => "1"}, false, {}, [], nil]) }

      assert_equal "X::Post reads format 1 of Marshal, not 2", error.message
      error = assert_raises(UnsupportedMarshalFormat) { Post.allocate.marshal_load(["1", {"id" => "1"}, false, {}, [], nil]) }

      assert_equal 'X::Post reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { Post.allocate.marshal_load({"id" => "1"}) }
    end
  end
end
