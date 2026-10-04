# frozen_string_literal: true

require "yaml"
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

    def test_media_a_later_release_added_to_reads_back_as_it_was
      loaded = UploadedMedia.allocate.tap { |media| media.marshal_load([1, ATTRS, "added"]) }

      assert_equal @media, loaded
    end

    def test_media_of_another_format_is_refused
      error = assert_raises(UnsupportedFormat) { UploadedMedia.allocate.marshal_load(["1", ATTRS]) }

      assert_equal 'X::UploadedMedia reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedFormat) { UploadedMedia.allocate.marshal_load(ATTRS) }
    end

    def test_media_whose_attributes_are_not_a_hash_is_refused
      assert_raises(ArgumentError) { UploadedMedia.allocate.marshal_load([1, "x"]) }
    end

    def test_yaml_writes_the_state_marshal_writes_under_its_names
      assert_equal({"format" => 1, "attrs" => ATTRS}, YAML.unsafe_load(YAML.dump(@media).sub("!ruby/object:X::UploadedMedia", "")))
    end

    def test_media_written_as_yaml_reads_back_deep_frozen
      loaded = YAML.unsafe_load(YAML.dump(@media))

      assert_equal @media, loaded
      assert_equal [true] * 4, [loaded, loaded.attrs, loaded.attrs["id"], loaded.processing_info].map(&:frozen?)
      assert_equal @media, YAML.unsafe_load("#{YAML.dump(@media)}added: true\n")
    end

    def test_media_written_as_yaml_of_another_format_is_refused
      error = assert_raises(UnsupportedFormat) { YAML.unsafe_load(YAML.dump(@media).sub("format: 1", "format: 2")) }

      assert_equal "X::UploadedMedia reads format 1 of Marshal, not 2", error.message
      assert_raises(UnsupportedFormat) { YAML.unsafe_load("--- !ruby/object:X::UploadedMedia\nformat: 2\n") }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { UploadedMedia::MARSHAL_FORMAT }
    end
  end
end
