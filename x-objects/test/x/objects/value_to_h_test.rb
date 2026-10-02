# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A resource and each value of the object layer is a Hash of its attributes, and builds a Hash of the pairs a block
  # returns for them, as the to_h of a Hash does, rather than ignore the block
  class ValueToHTest < Minitest::Test
    cover Objects.const_get(:Serialization)

    VALUES = {
      User => {"id" => "1", "username" => "sferik"},
      Trend => {"trend_name" => "#ruby", "tweet_count" => 1},
      PersonalizedTrend => {"trend_name" => "#ruby", "post_count" => "1K posts"},
      PostUsage => {"project_id" => "1", "project_usage" => "2"},
      MatchingRule => {"id" => "1", "tag" => "ruby"}
    }.freeze

    def test_a_value_is_a_hash_of_its_attributes
      VALUES.each do |klass, attrs|
        value = klass.new(attrs)

        assert_same value.attrs, value.to_h, klass.name
      end
    end

    def test_a_value_builds_a_hash_of_the_pairs_a_block_returns
      VALUES.each do |klass, attrs|
        assert_equal attrs.transform_keys(&:to_sym), klass.new(attrs).to_h { |key, value| [key.to_sym, value] }, klass.name
      end
    end
  end
end
