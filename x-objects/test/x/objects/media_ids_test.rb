# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class MediaIdsTest < Minitest::Test
      cover MediaIds

      def test_media_id_of
        assert_equal "3", MediaIds.media_id_of({"id" => "3", "media_key" => "3_3"})
        assert_equal "3", MediaIds.media_id_of({"id" => 3})
        assert_equal "3", MediaIds.media_id_of(Class.new(Hash).new.merge!("id" => "3"))
        assert_equal "3", MediaIds.media_id_of(3)
        assert_equal "3", MediaIds.media_id_of("3")
      end

      def test_media_id_of_uploaded_media_that_is_no_hash
        uploaded = Struct.new(:attrs) { def fetch(key) = attrs.fetch(key) }

        assert_equal "3", MediaIds.media_id_of(uploaded.new({"id" => "3"}))
        assert_raises(KeyError) { MediaIds.media_id_of(uploaded.new({"media_key" => "3_3"})) }
      end

      def test_media_id_of_media
        assert_equal "1880028106020515840", MediaIds.media_id_of(Media.new({"media_key" => "3_1880028106020515840", "type" => "photo"}))
        assert_equal "7", MediaIds.media_id_of(Struct.new(:media_key).new("13_7"))
      end

      def test_media_id_of_something_that_is_not_media
        [Object.new, Struct.new(:media_key).new(nil), Struct.new(:media_key).new("3_"), Struct.new(:media_key).new("x3_7"), :media].each do |value|
          error = assert_raises(ArgumentError, value.inspect) { MediaIds.media_id_of(value) }

          assert_equal "media is what an upload returned, media such as X::Media, a media key, or a media identifier, not #{value.inspect}", error.message
        end
      end

      def test_media_id_of_a_media_key
        assert_equal "1880028106020515840", MediaIds.media_id_of("3_1880028106020515840")
        assert_equal %w[7 8], MediaIds.media_ids_of(%w[3_7 13_8])
      end

      def test_media_id_of_the_id_of_media
        assert_equal "7", MediaIds.media_id_of(Media.new({"media_key" => "3_7", "type" => "photo"}).id)
      end

      def test_media_id_of_what_names_no_identifier_the_api_takes
        ["abc", " 7", "-7", "7 ", "", "3_", "_7", "1" * 20, -7, {"id" => "abc"}, {"id" => nil}].each do |value|
          error = assert_raises(ArgumentError, value.inspect) { MediaIds.media_id_of(value) }

          assert_equal "media is what an upload returned, media such as X::Media, a media key, or a media identifier, not #{value.inspect}", error.message
        end
      end

      def test_media_id_of_the_longest_identifier_the_api_takes
        assert_equal "9" * 19, MediaIds.media_id_of("9" * 19)
      end

      def test_media_ids_of_many
        assert_equal %w[3 4 5], MediaIds.media_ids_of([{"id" => 3}, "4", 5])
        assert_empty MediaIds.media_ids_of([])
      end

      def test_media_ids_of_an_array_subclass
        assert_equal %w[3 4], MediaIds.media_ids_of(Class.new(Array).new(%w[3 4]))
      end

      def test_media_ids_of_none
        assert_empty MediaIds.media_ids_of(nil)
      end

      def test_media_ids_of_one
        assert_equal %w[3], MediaIds.media_ids_of({"id" => "3"})
        assert_equal %w[4], MediaIds.media_ids_of("4")
        assert_equal %w[5], MediaIds.media_ids_of(5)
      end

      def test_media_id_of_a_response_without_an_id
        upload = Class.new { def fetch(key) = yield(key) }.new
        upload.define_singleton_method(:inspect) { "#<upload>" }
        [{"media_key" => "3_3"}, {id: "3"}, upload].each do |value|
          error = assert_raises(ArgumentError, value.inspect) { MediaIds.media_id_of(value) }

          assert_equal "media is what an upload returned, media such as X::Media, a media key, or a media identifier, not #{value.inspect}, " \
            "which holds no \"id\"", error.message
        end
      end
    end
  end
end
