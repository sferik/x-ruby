# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A trend, a personalized trend, and the usage of a project have no identifier, so each equals another of its
  # class that holds the same attributes
  class ValueEqualityTest < Minitest::Test
    cover Objects::ValueEquality

    def test_objects_of_the_same_attributes_are_equal_and_share_a_hash
      [Trend, PersonalizedTrend, Usage].each do |klass|
        first = klass.new({"trend_name" => "#ruby", "tweet_count" => 1})
        second = klass.new({"tweet_count" => 1, "trend_name" => "#ruby"})

        assert_equal first, second
        assert first.eql?(second)
        assert_equal first.hash, second.hash
        assert_equal [first], [first, second].uniq
      end
    end

    def test_objects_of_other_attributes_are_not_equal
      first = Trend.new({"trend_name" => "#ruby"})
      second = Trend.new({"trend_name" => "#crystal"})

      refute_equal first, second
      refute_equal first.hash, second.hash
    end

    def test_objects_of_another_class_are_not_equal
      attrs = {"trend_name" => "#ruby"}

      refute_equal Trend.new(attrs), PersonalizedTrend.new(attrs)
      refute_equal Trend.new(attrs).hash, PersonalizedTrend.new(attrs).hash
      refute_equal Trend.new(attrs), Class.new(Trend).new(attrs)
      refute_equal Trend.new(attrs), attrs
    end
  end
end
