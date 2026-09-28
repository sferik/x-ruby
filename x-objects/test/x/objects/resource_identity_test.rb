# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class ResourceIdentityTest < Minitest::Test
      cover Resource
      cover Objects::Finders
      cover Objects::BatchFinders
      cover Identity

      def setup
        @client = FakeClient.new
        @user = User.new({"id" => "1", "username" => "sferik"}, client: @client)
      end

      def test_class_defaults
        assert_nil Resource.__send__(:endpoint)
        assert_equal "id", Resource.__send__(:id_key)
        assert_nil Resource.__send__(:includes_key)
        assert_empty Resource.default_params
      end

      def test_endpoint_bang
        assert_equal "users", User.__send__(:endpoint!)
        error = assert_raises(UnsupportedOperation) { Poll.__send__(:endpoint!) }

        assert_equal "X::Poll cannot be fetched by id", error.message
      end

      # A resource the API offers no lookup of answers no finder, rather than one that only raises
      def test_a_resource_without_a_lookup_answers_no_finder
        [Resource, Poll, Place].each do |resource|
          %i[find find! find_all hydrate_all].each { |name| refute_respond_to resource, name }
        end
      end

      def test_a_resource_without_a_lookup_is_built_from_an_identifier
        assert_equal [1, "abc"], [Poll.from_id(1).id, Place.from_id("abc").id]
        assert_equal Place.new({"id" => "abc", "name" => "Home"}), Place.from_id("abc")
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

      def test_refuses_an_identifier_that_is_not_one
        error = assert_raises(ArgumentError) { User.new({"id" => "abc"}) }

        assert_equal "\"abc\" is not an identifier: pass X::User, an Integer, or a String of digits", error.message
        assert_raises(ArgumentError) { Space.new({"id" => "a/b"}) }
        assert_raises(ArgumentError) { Media.new({"media_key" => ""}) }
      end

      def test_takes_the_identifiers_the_api_gives
        assert_equal [7_505_382, "1DXxyRYNejbKM", "3_1", "01a9a39529b27f36"],
          [User.new({"id" => "7505382"}), Space.new({"id" => "1DXxyRYNejbKM"}), Media.new({"media_key" => "3_1"}), Place.new({"id" => "01a9a39529b27f36"})].map(&:id)
      end

      def test_frozen
        assert_predicate @user, :frozen?
      end

      def test_id
        assert_equal 1, @user.id
      end

      def test_client_and_includes
        assert_same @client, @user.client
        assert_instance_of Includes, @user.send(:includes)
        assert_nil User.new({"id" => "1"}).client
      end

      def test_includes_is_private
        refute_respond_to @user, :includes
      end

      def test_each_resource_gets_its_own_identity_map
        refute_same User.new({"id" => "1"}).send(:includes), User.new({"id" => "1"}).send(:includes)
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
