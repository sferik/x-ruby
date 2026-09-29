# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class MediaIdTest < Minitest::Test
    cover Media

    def test_media_is_identified_by_its_media_key
      media = Media.new({"media_key" => "3_1880028106020515840"})

      assert_equal ["3_1880028106020515840", "3_1880028106020515840"], [media.id, media.media_key]
    end

    def test_the_media_identifier_is_the_number_the_media_key_names
      assert_equal 1_880_028_106_020_515_840, Media.from_id("3_1880028106020515840").media_id
      assert_equal [1, 10], [Media.new({"media_key" => "16_1"}).media_id, Media.from_id("3_010").media_id]
    end

    def test_a_media_key_that_names_no_identifier
      error = assert_raises(InvalidAttribute) { Media.from_id("abc").media_id }

      assert_equal 'X::Media#media_id cannot be read from "abc"', error.message
      assert_raises(InvalidAttribute) { Media.from_id("3_").media_id }
    end
  end
end
