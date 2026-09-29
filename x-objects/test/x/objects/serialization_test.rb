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
      @post = Post.__send__(:build, {"id" => "1", "text" => "Hello", "author_id" => "9"}, client: @client, includes:)
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

      assert_equal [@post.attrs], page.as_json
      assert_equal [@post.attrs], JSON.parse(page.to_json)
      assert_equal JSON.pretty_generate([@post.attrs]), JSON.pretty_generate(page)
    end

    def test_a_page_is_serialized_as_plain_data
      as_json = Page.new([@post], {"result_count" => 1}).as_json

      assert_same @post.attrs, as_json.first
      assert_predicate as_json, :frozen?
    end

    def test_a_cursor_refuses_to_serialize_every_resource_it_would_page
      cursor = paged_followers

      [-> { cursor.as_json }, -> { cursor.to_json }, -> { cursor.to_json(JSON::State.new) }].each do |serialize|
        error = assert_raises(UnsupportedOperation, &serialize)
        assert_equal "Serializing a cursor would read every page of its collection, a billed request per page; " \
          "serialize cursor.first(n), or cursor.to_a to read every page", error.message
      end
      assert_empty @client.requests
    end

    def test_a_cursor_refuses_to_be_marshalled
      cursor = paged_followers
      cursor.first

      error = assert_raises(UnsupportedOperation) { Marshal.dump(cursor) }
      assert_equal "Serializing a cursor would read every page of its collection, a billed request per page; " \
        "serialize cursor.first(n), or cursor.to_a to read every page", error.message
      assert_raises(UnsupportedOperation) { Marshal.dump({"followers" => cursor}) }
    end

    def test_a_cursor_refuses_to_serialize_through_an_encoder
      cursor = paged_followers

      assert_raises(UnsupportedOperation) { JSON.generate({"followers" => cursor}) }
      assert_empty @client.requests
    end

    def test_what_a_cursor_reads_serializes
      assert_equal [{"id" => "1"}, {"id" => "2"}], JSON.parse(paged_followers.to_a.to_json)
    end

    private

    # A cursor over two pages of one follower each
    def paged_followers
      @client.stub(:get, "users/9/followers", ->(query, _) { {"data" => [{"id" => query["pagination_token"] ? "2" : "1"}], "meta" => {"next_token" => (query["pagination_token"] ? nil : "p2")}} })
      User.from_id(9, client: @client).followers
    end
  end
end
