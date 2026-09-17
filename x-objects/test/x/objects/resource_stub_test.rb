require_relative "../../test_helper"

module X
  module Objects
    class ResourceStubTest < Minitest::Test
      cover Resource
      cover Objects::Finders

      def setup
        @client = FakeClient.new
      end

      def test_from_id
        user = User.from_id(7505382, client: @client)

        assert_equal({"id" => "7505382"}, user.attrs)
        assert_same @client, user.client
        refute_predicate user, :hydrated?
        assert_predicate user, :stub?
      end

      def test_from_id_accepts_a_resource_and_a_string
        assert_equal 1, User.from_id(User.new({"id" => "1"})).id
        assert_equal 1, User.from_id("1").id
        assert_nil User.from_id("1").client
      end

      def test_from_id_uses_the_id_key
        assert_equal({"media_key" => "3_1"}, Media.from_id("3_1").attrs)
      end

      def test_from_id_hydrates
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "name" => "Erik Berlin"}})

        assert_equal "Erik Berlin", User.from_id(1, client: @client).hydrate.name
      end

      def test_from_id_builds_cursors_without_a_request
        assert_equal "users/1/followers", User.from_id(1, client: @client).followers.path
        assert_empty @client.requests
      end

      def test_stub_predicate
        assert_predicate User.new({"id" => "1"}), :stub?
        refute_predicate User.new({"id" => "1", "username" => "sferik"}), :stub?
        refute_predicate User.new({"id" => "1", "name" => nil}), :stub?
        assert_predicate Media.new({"media_key" => "3_1"}), :stub?
      end

      def test_stub_predicate_for_references
        post = Post.new({"id" => "1", "author_id" => "9"}, includes: Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]}))

        refute_predicate post.author, :stub?
        assert_predicate Post.new({"id" => "1", "author_id" => "8"}).author, :stub?
      end

      def test_fields_key_defaults_to_nil
        assert_nil Resource.fields_key
        assert_nil Poll.fields_key
        assert_nil Poll.fields_key
        assert_nil Place.fields_key
      end

      def test_fields_keys
        assert_equal %w[user.fields post.fields list.fields dm_event.fields space.fields community.fields],
          [User, Post, List, DirectMessage, Space, Community].map(&:fields_key)
      end
    end
  end
end
