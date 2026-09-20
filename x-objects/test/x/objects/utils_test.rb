# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class UtilsTest < Minitest::Test
      cover Utils

      def test_deep_freeze_copies_hash_with_string_keys
        original = {id: "1", nested: {list: ["a"]}}
        frozen = Utils.deep_freeze(original)

        assert_equal({"id" => "1", "nested" => {"list" => ["a"]}}, frozen)
        assert_predicate frozen, :frozen?
        assert_predicate frozen["nested"], :frozen?
        assert_predicate frozen["nested"]["list"], :frozen?
      end

      def test_deep_freeze_does_not_freeze_original
        original = {"id" => +"1"}
        frozen = Utils.deep_freeze(original)

        refute_predicate original, :frozen?
        refute_predicate original["id"], :frozen?
        assert_predicate frozen["id"], :frozen?
        refute_same original["id"], frozen["id"]
      end

      def test_deep_freeze_freezes_array_elements
        frozen = Utils.deep_freeze([+"a", {b: 1}])

        assert_equal(["a", {"b" => 1}], frozen)
        assert_predicate frozen, :frozen?
        assert_predicate frozen[0], :frozen?
        assert_predicate frozen[1], :frozen?
      end

      def test_deep_freeze_returns_other_values_unchanged
        assert_equal 1, Utils.deep_freeze(1)
        assert_nil Utils.deep_freeze(nil)
        assert Utils.deep_freeze(true)
      end

      def test_path_without_params
        assert_equal "users/1", Utils.path("users/1", {})
      end

      def test_path_without_params_after_normalization
        assert_equal "users/1", Utils.path("users/1", {"a" => nil})
      end

      def test_path_with_params
        assert_equal "users?ids=1%2C2&max_results=10", Utils.path("users", {:ids => %w[1 2], "max_results" => 10})
      end

      def test_query_stringifies_keys_and_joins_arrays
        assert_equal({"ids" => "1,2", "max_results" => 10}, Utils.query({:ids => %w[1 2], "max_results" => 10}))
      end

      def test_query_joins_array_subclasses
        assert_equal({"ids" => "1,2"}, Utils.query({ids: Class.new(Array).new(%w[1 2])}))
      end

      def test_query_drops_nil_values
        assert_equal({"a" => "b"}, Utils.query({a: "b", c: nil}))
      end

      def test_query_keeps_false_values
        assert_equal({"a" => false}, Utils.query({a: false}))
      end

      def test_merge_params_overrides_and_drops_nil
        merged = Utils.merge_params({"a" => %w[1 2], "b" => "x", "c" => "y"}, {a: "3", c: nil, d: 4})

        assert_equal({"a" => "3", "b" => "x", "d" => 4}, merged)
      end

      def test_merge_params_with_mixed_key_types
        assert_equal({"a" => "2"}, Utils.merge_params({"a" => "1"}, {a: "2"}))
        assert_equal({"a" => "2"}, Utils.merge_params({a: "1"}, {"a" => "2"}))
        assert_equal({"b" => "1"}, Utils.merge_params({"a" => "1", "b" => "1"}, {a: nil}))
      end

      def test_merge_params_without_overrides
        assert_equal({"a" => "1,2"}, Utils.merge_params({a: %w[1 2]}, {}))
      end

      def test_id_of_resource
        assert_equal "7505382", Utils.id_of(User.new({"id" => "7505382"}))
      end

      def test_id_of_object_with_integer_id
        assert_equal "7505382", Utils.id_of(Struct.new(:id).new(7505382))
      end

      def test_id_of_integer
        assert_equal "7505382", Utils.id_of(7505382)
      end

      def test_id_of_string
        assert_equal "7505382", Utils.id_of("7505382")
      end

      def test_id_predicate_for_resource
        assert Utils.id?(User.new({"id" => "1"}))
      end

      def test_id_predicate_for_integer
        assert Utils.id?(7505382)
      end

      def test_id_predicate_for_numeric_string
        refute Utils.id?("7505382")
      end

      def test_id_predicate_for_username
        refute Utils.id?("sferik")
        refute Utils.id?("sferik1")
        refute Utils.id?("1sferik")
        refute Utils.id?("12\n34")
        refute Utils.id?("")
      end

      def test_time_parses_iso8601
        assert_equal Time.utc(2007, 5, 9, 1, 51, 3), Utils.time("2007-05-09T01:51:03.000Z")
      end

      def test_time_with_nil
        assert_nil Utils.time(nil)
      end
    end
  end
end
