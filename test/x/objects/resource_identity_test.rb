require_relative "../../test_helper"

module X
  module Objects
    class ResourceIdentityTest < Minitest::Test
      cover Resource
      cover Identity

      def setup
        @client = FakeClient.new
        @user = User.new({"id" => "1", "username" => "sferik"}, client: @client)
      end

      def test_class_defaults
        assert_nil Resource.endpoint
        assert_equal "id", Resource.id_key
        assert_nil Resource.includes_key
        assert_empty Resource.default_params
      end

      def test_endpoint_bang
        assert_equal "users", User.endpoint!
        error = assert_raises(NotImplementedError) { Media.endpoint! }

        assert_equal "X::Media cannot be fetched by media_key", error.message
      end

      def test_find_without_endpoint
        assert_raises(NotImplementedError) { Media.find("3_1", client: FakeClient.new) }
        assert_raises(NotImplementedError) { Media.find_all(["3_1"], client: FakeClient.new) }
      end

      def test_hydratable
        refute_predicate Resource, :hydratable?
        assert_predicate User, :hydratable?
      end

      def test_attrs_are_deep_frozen_with_string_keys
        user = User.new({id: "1", public_metrics: {followers_count: 1}})

        assert_equal({"id" => "1", "public_metrics" => {"followers_count" => 1}}, user.attrs)
        assert_predicate user.attrs, :frozen?
        assert_predicate user.attrs["public_metrics"], :frozen?
      end

      def test_to_h
        assert_same @user.attrs, @user.to_h
      end

      def test_requires_id
        error = assert_raises(ArgumentError) { User.new({"username" => "sferik"}) }

        assert_equal "X::User requires id", error.message
        assert_raises(ArgumentError) { User.new({"id" => nil}) }
      end

      def test_requires_id_key_of_class
        assert_raises(ArgumentError) { Media.new({"id" => "1"}) }
        assert_equal "3_1", Media.new({"media_key" => "3_1"}).id
      end

      def test_frozen
        assert_predicate @user, :frozen?
      end

      def test_id
        assert_equal "1", @user.id
      end

      def test_client_and_includes
        assert_same @client, @user.client
        assert_instance_of Includes, @user.includes
        assert_nil User.new({"id" => "1"}).client
      end

      def test_each_resource_gets_its_own_identity_map
        refute_same User.new({"id" => "1"}).includes, User.new({"id" => "1"}).includes
      end

      def test_equality_by_id
        assert_equal @user, User.new({"id" => "1"})
        assert_operator @user, :eql?, User.new({"id" => "1"})
        refute_equal @user, User.new({"id" => "2"})
      end

      def test_equality_by_class
        refute_equal @user, Post.new({"id" => "1"})
        refute_equal @user, "1"
        refute_nil @user
      end

      def test_hash_by_class_and_id
        assert_equal @user.hash, User.new({"id" => "1"}).hash
        refute_equal @user.hash, User.new({"id" => "2"}).hash
        refute_equal @user.hash, Post.new({"id" => "1"}).hash
        assert_equal 1, [@user, User.new({"id" => "1"})].uniq.size
      end

      def test_hydrated
        refute_predicate @user, :hydrated?
        assert_predicate User.new({"id" => "1"}, hydrated: true), :hydrated?
      end

      def test_inspect
        assert_equal '#<X::User id="1" username="sferik">', @user.inspect
      end
    end
  end
end
