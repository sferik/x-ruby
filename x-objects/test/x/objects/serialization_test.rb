# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class SerializationTest < Minitest::Test
    cover Resource
    cover Objects::Serialization
    cover Problem
    cover Usage
    cover Page
    cover Cursor

    # A client that holds credentials, as X::Client does, which must never be serialized
    class CredentialedClient < FakeClient
      attr_reader :access_token, :access_token_secret

      def initialize
        super
        @access_token = "9-token"
        @access_token_secret = "s3cr3t"
      end
    end

    def setup
      @client = CredentialedClient.new
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
      @post = Post.new({"id" => "1", "text" => "Hello", "author_id" => "9"}, client: @client, includes:)
    end

    def test_as_json_is_the_attributes
      assert_equal({"id" => "1", "text" => "Hello", "author_id" => "9"}, @post.as_json)
      assert_same @post.attrs, @post.as_json
    end

    def test_as_json_takes_the_options_active_support_passes
      assert_equal @post.attrs, @post.as_json({only: :id})
    end

    def test_as_json_holds_no_credential_even_after_a_reference_resolves
      @post.author

      assert_equal "sferik", @post.author.username
      refute_includes @post.as_json.to_s, "s3cr3t"
      refute_includes @post.to_json, "s3cr3t"
    end

    def test_to_json_is_the_attributes_as_json
      assert_equal "{\"id\":\"1\",\"text\":\"Hello\",\"author_id\":\"9\"}", @post.to_json
      assert_equal @post.attrs, JSON.parse(@post.to_json)
    end

    def test_to_json_takes_the_state_an_encoder_passes
      assert_equal JSON.pretty_generate(@post.attrs), JSON.pretty_generate(@post)
    end

    def test_a_resource_nested_in_a_structure_is_serialized_by_its_attributes
      assert_equal "{\"post\":{\"id\":\"1\",\"text\":\"Hello\",\"author_id\":\"9\"}}", JSON.generate({post: @post})
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
      assert_raises(ArgumentError) { loaded.hydrate }
      refute_predicate loaded, :hydrated?
    end

    def test_marshal_dump_is_the_attributes
      assert_equal @post.attrs, @post.marshal_dump
    end

    def test_a_marshalled_resource_keeps_no_reference
      loaded = Marshal.load(Marshal.dump(@post))

      assert_predicate loaded.author, :stub?
      assert_empty loaded.problems
    end

    def test_a_problem_serializes_its_attributes
      problem = Problem.new({"title" => "Not Found Error", "detail" => "Gone"})

      assert_equal({"title" => "Not Found Error", "detail" => "Gone"}, problem.as_json)
      assert_equal problem.attrs, JSON.parse(problem.to_json)
      assert_equal JSON.pretty_generate(problem.attrs), JSON.pretty_generate(problem)
    end

    def test_a_usage_serializes_its_attributes
      usage = Usage.new({"project_usage" => "1234"})

      assert_equal({"project_usage" => "1234"}, usage.as_json)
      assert_equal usage.attrs, JSON.parse(usage.to_json)
      assert_equal JSON.pretty_generate(usage.attrs), JSON.pretty_generate(usage)
    end

    def test_a_page_serializes_its_resources
      page = Page.new([@post], {"result_count" => 1})

      assert_equal [@post], page.as_json
      assert_equal [@post.attrs], JSON.parse(page.to_json)
      assert_equal JSON.pretty_generate([@post.attrs]), JSON.pretty_generate(page)
    end

    def test_a_cursor_serializes_every_resource_it_pages
      cursor = paged_followers

      assert_equal %w[1 2], cursor.as_json.map { |user| user.attrs.fetch("id") }
      assert_equal [{"id" => "1"}, {"id" => "2"}], JSON.parse(cursor.to_json)
    end

    def test_a_cursor_serializes_through_an_encoder
      assert_equal JSON.pretty_generate([{"id" => "1"}, {"id" => "2"}]), JSON.pretty_generate(paged_followers)
    end

    private

    # A cursor over two pages of one follower each
    def paged_followers
      @client.stub(:get, "users/9/followers", ->(query, _) { {"data" => [{"id" => query["pagination_token"] ? "2" : "1"}], "meta" => {"next_token" => (query["pagination_token"] ? nil : "p2")}} })
      User.from_id(9, client: @client).followers
    end
  end
end
