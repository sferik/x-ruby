# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What is built of attributes refuses attributes that are not a Hash where it is built, rather than from a reader
  class AttributesValidationTest < Minitest::Test
    cover Objects.const_get(:Utils)
    cover Resource
    cover Trend
    cover PersonalizedTrend
    cover PostUsage

    NOT_A_HASH = [nil, "id", [["id", "1"]], 1].freeze

    def test_a_resource_refuses_attributes_that_are_not_a_hash
      assert_equal NOT_A_HASH.map { |attrs| "attrs must be a Hash, not #{attrs.inspect}" }, messages { |attrs| User.new(attrs) }
    end

    def test_a_trend_and_the_usage_refuse_attributes_that_are_not_a_hash
      [Trend, PersonalizedTrend, PostUsage].each do |klass|
        assert_equal NOT_A_HASH.map { |attrs| "attrs must be a Hash, not #{attrs.inspect}" }, messages { |attrs| klass.new(attrs) }
      end
    end

    def test_what_converts_to_a_hash_is_taken_as_one
      attrs = Struct.new(:to_hash).new({"id" => "1", "trend_name" => "#ruby"})

      assert_equal({"id" => "1", "trend_name" => "#ruby"}, User.new(attrs).attrs)
      assert_equal "#ruby", Trend.new(attrs).name
    end

    private

    # The message each attributes that are not a Hash raise ArgumentError with
    def messages(&) = NOT_A_HASH.map { |attrs| assert_raises(ArgumentError) { yield attrs }.message }
  end
end
