# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PlaceTest < Minitest::Test
    cover Place

    def setup
      @place = Place.new({"id" => "p1", "name" => "San Francisco", "full_name" => "San Francisco, CA", "country" => "United States",
                          "country_code" => "US", "place_type" => "city", "contained_within" => ["p0"],
                          "geo" => {"type" => "Feature"}})
    end

    def test_class_configuration
      assert_equal "places", Place.includes_key
      assert_nil Place.endpoint
    end

    def test_attributes
      assert_equal "San Francisco", @place.name
      assert_equal "San Francisco, CA", @place.full_name
      assert_equal "United States", @place.country
      assert_equal "US", @place.country_code
      assert_equal "city", @place.place_type
    end

    def test_more_attributes
      assert_equal ["p0"], @place.contained_within
      assert_equal({"type" => "Feature"}, @place.geo)
    end
  end
end
