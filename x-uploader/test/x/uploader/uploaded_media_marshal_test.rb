# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Marshal writes uploaded media as plain data, led by the number of its format, and reads it back deep-frozen
  class UploadedMediaMarshalTest < Minitest::Test
    cover UploadedMedia

    ATTRS = {"id" => "1880028106020515840", "media_key" => "3_1880028106020515840", "processing_info" => {"state" => "pending"}}.freeze

    def setup
      @media = UploadedMedia.new(ATTRS)
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [1, ATTRS], @media.marshal_dump
    end

    def test_marshalled_media_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@media))

      assert_equal @media, loaded
      assert_equal [UploadedMedia, 1_880_028_106_020_515_840, "pending"], [loaded.class, loaded.id, loaded.state]
    end

    def test_marshalled_media_reads_back_deep_frozen
      loaded = Marshal.load(Marshal.dump(@media))

      assert_equal [true] * 4, [loaded, loaded.attrs, loaded.attrs["id"], loaded.processing_info].map(&:frozen?)
    end

    def test_media_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { UploadedMedia.allocate.marshal_load(["1", ATTRS]) }

      assert_equal 'X::UploadedMedia reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { UploadedMedia.allocate.marshal_load(ATTRS) }
    end

    def test_media_whose_attributes_are_not_a_hash_is_refused
      assert_raises(ArgumentError) { UploadedMedia.allocate.marshal_load([1, "x"]) }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { UploadedMedia::MARSHAL_FORMAT }
    end
  end
end
