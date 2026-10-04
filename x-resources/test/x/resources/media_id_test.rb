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

    def test_what_is_not_a_media_key_is_not_an_identifier_of_media
      message = "%s is not an identifier: pass X::Media, what an upload returned, or a media key, such as \"3_1880028106020515840\""

      ["abc", "3_", "_1", "1880028106020515840", "3_1\n"].each do |id|
        assert_equal format(message, id.inspect), assert_raises(ArgumentError) { Media.from_id(id) }.message
      end
      assert_raises(ArgumentError) { Media.from_id(1_880_028_106_020_515_840) }
      assert_raises(ArgumentError) { Media.new({"media_key" => "1880028106020515840"}) }
    end

    def test_media_is_not_looked_up_by_its_numeric_identifier
      client = Object.new

      assert_raises(ArgumentError) { Media.find(1_880_028_106_020_515_840, client:) }
      assert_raises(ArgumentError) { Media.find!("1880028106020515840", client:) }
      assert_raises(ArgumentError) { Media.find_all(["3_1", "1880028106020515840"], client:) }
    end
  end
end
