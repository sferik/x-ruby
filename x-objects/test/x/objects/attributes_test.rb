require_relative "../../test_helper"

module X
  module Objects
    class AttributesTest < Minitest::Test
      cover Attributes

      ATTRS = {"id" => "1", "name" => "w", "created_at" => "2007-05-09T01:51:03.000Z", "active" => true,
               "metrics" => {"count" => 5}, "owner_id" => "9", "meta" => {"owner_id" => "8"}, "member_ids" => %w[2 3]}.freeze

      def setup
        @client = FakeClient.new
        @klass = Class.new(Resource) do
          attribute :name
          attribute :created_at, :time
          attribute :active, :boolean
          attribute :count, key: %w[metrics count]
        end
        @widget = @klass.new(ATTRS, client: @client)
      end

      def test_the_macros_are_private_to_the_class_body
        %i[attribute reference references].each { |macro| refute_respond_to @klass, macro }
      end

      def test_raw_attribute
        assert_equal "w", @widget.name
        assert_nil @klass.new({"id" => "1"}).name
      end

      def test_attribute_returns_value_unchanged
        widget = @klass.new({"id" => "1", "name" => ["a"]})

        assert_equal ["a"], widget.name
        assert_same widget.attrs["name"], widget.name
      end

      def test_attribute_with_explicit_key
        klass = Class.new(Resource) { attribute :label, key: %w[name] }

        assert_equal "w", klass.new(ATTRS).label
        refute_respond_to klass.new(ATTRS), :name
      end

      def test_time_attribute
        assert_equal Time.utc(2007, 5, 9, 1, 51, 3), @widget.created_at
        assert_nil @klass.new({"id" => "1"}).created_at
      end

      def test_boolean_attribute
        assert @widget.active
        assert_predicate @widget, :active?
      end

      def test_false_boolean_attribute
        widget = @klass.new({"id" => "1", "active" => false})

        refute widget.active
        refute_predicate widget, :active?
      end

      def test_missing_boolean_attribute
        widget = @klass.new({"id" => "1"})

        assert_nil widget.active
        refute_predicate widget, :active?
      end

      def test_truthy_non_boolean_attribute_is_not_predicate_true
        assert_equal "yes", @klass.new({"id" => "1", "active" => "yes"}).active
        refute_predicate @klass.new({"id" => "1", "active" => "yes"}), :active?
      end

      def test_predicate_only_defined_for_boolean
        refute_respond_to @widget, :name?
        refute_respond_to @widget, :created_at?
        refute_respond_to @widget, :count?
      end

      def test_nested_boolean_predicate
        klass = Class.new(Resource) { attribute :flag, :boolean, key: %w[meta flag] }

        assert_predicate klass.new({"id" => "1", "meta" => {"flag" => true}}), :flag?
      end

      def test_nested_attribute
        assert_equal 5, @widget.count
        assert_nil @klass.new({"id" => "1"}).count
        assert_nil @klass.new({"id" => "1", "metrics" => {}}).count
      end

      def test_string_keys_are_rejected
        error = assert_raises(ArgumentError) { Class.new(Resource) { attribute :name, key: "name" } }

        assert_equal 'key must be an Array of keys, not "name"', error.message
      end

      def test_array_subclass_keys_are_accepted
        klass = Class.new(Resource) { attribute :label, key: Class.new(Array).new(["name"]) }

        assert_equal "w", klass.new(ATTRS).label
      end

      def test_unknown_type
        error = assert_raises(KeyError) { Class.new(Resource) { attribute :bogus, :bogus } }

        assert_match(/bogus/, error.message)
      end

      def test_converters
        assert_equal "x", Attributes::CONVERTERS.fetch(:raw).call("x")
        assert_equal false, Attributes::CONVERTERS.fetch(:boolean).call(false) # rubocop:disable Minitest/RefuteFalse
        assert_equal Time.utc(2007, 5, 9), Attributes::CONVERTERS.fetch(:time).call("2007-05-09T00:00:00Z")
        assert_predicate Attributes::CONVERTERS, :frozen?
      end
    end
  end
end
