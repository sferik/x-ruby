# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"
require "x/uploader/signature"
require "x/uploader/source"
require "x/uploader/validator"

module X
  class SignatureTest < Minitest::Test
    cover Uploader.const_get(:Signature)

    SIGNED = {
      "image/gif" => ["GIF87a", "GIF89a"],
      "image/png" => ["\x89PNG\r\n\x1A\n"],
      "image/jpeg" => ["\xFF\xD8\xFF\xE0"],
      "image/bmp" => ["BM\x00\x00"],
      "image/tiff" => ["II*\x00", "MM\x00*"],
      "image/webp" => ["RIFF\x00\x00\x00\x00WEBPVP8 "],
      "video/webm" => ["\x1A\x45\xDF\xA3"],
      "video/quicktime" => ["\x00\x00\x00\x14ftypqt  "],
      "video/mp4" => ["isom", "iso2", "iso3", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "M4V ", "M4VH", "M4VP", "dash", "MSNV"]
        .map { |brand| "\x00\x00\x00\x18ftyp#{brand}" },
      "model/gltf-binary" => ["glTF\x02\x00\x00\x00"],
      "text/vtt" => ["WEBVTT\n\n", "\xEF\xBB\xBFWEBVTT\n"],
      "video/mp2t" => [("G" + ("\xFF" * 187)) * 3, ("\x00\x00\x00\x00G" + ("\xFF" * 187)) * 3]
    }.freeze

    def test_every_signature_names_the_media_type_of_media_that_begins_with_it
      SIGNED.each do |media_type, signatures|
        signatures.each do |signature|
          assert_equal media_type, Uploader.const_get(:Signature).media_type(signature.b), signature.inspect
        end
      end
    end

    def test_media_no_signature_names_has_no_media_type
      ["", "not media at all", "RIFF\x00\x00\x00\x00AVI LIST", "PK\x03\x04", "1\n00:00:01,000 --> 00:00:02,000\n"].each do |bytes|
        assert_nil Uploader.const_get(:Signature).media_type(bytes.b), bytes.inspect
      end
    end

    def test_images_and_audio_that_share_the_box_type_of_an_mp4_video_are_not_one
      ["heic", "heix", "mif1", "msf1", "avif", "avis", "M4A ", "M4B "].each do |brand|
        assert_nil Uploader.const_get(:Signature).media_type("\x00\x00\x00\x18ftyp#{brand}".b), brand
      end
    end

    def test_media_with_the_sync_byte_of_a_transport_stream_in_too_few_packets_is_not_one
      [("G" + ("\xFF" * 187)) * 2, "G" + ("\xFF" * 400), ("\x00\x00\x00\x00G" + ("\xFF" * 187)) * 2].each do |bytes|
        assert_nil Uploader.const_get(:Signature).media_type(bytes.b)
      end
    end

    def test_the_media_type_of_media_shorter_than_the_signature_it_begins_with
      assert_nil Uploader.const_get(:Signature).media_type("GIF8")
    end

    def test_media_type_reads_the_signature_of_a_source
      source = Uploader.const_get(:Source).for(StringIO.new("GIF89a".b))

      assert_equal "image/gif", Uploader.const_get(:Signature).media_type!(source)
    end

    def test_the_category_a_signature_gives_media_is_one_the_api_takes
      categories = Uploader.const_get(:Signature)::CATEGORIES

      assert_equal %w[subtitles tweet_gif tweet_video], categories.values.uniq.sort
      assert_empty categories.values.uniq - Uploader.const_get(:Validator)::MEDIA_CATEGORIES
    end

    def test_the_category_a_signature_gives_media
      {
        "GIF89a" => "tweet_gif",
        "\x00\x00\x00\x18ftypmp42" => "tweet_video",
        "\x1A\x45\xDF\xA3" => "tweet_video",
        "WEBVTT\n" => "subtitles",
        "BM\x00\x00" => "tweet_image"
      }.each do |bytes, category|
        source = Uploader.const_get(:Source).for(StringIO.new(bytes.b))

        assert_equal category, Uploader.const_get(:Signature).media_category!(source), bytes.inspect
      end
    end

    def test_a_transport_stream_is_a_video
      source = Uploader.const_get(:Source).for(StringIO.new((("G" + ("\xFF" * 187)) * 3).b))

      assert_equal "tweet_video", Uploader.const_get(:Signature).media_category!(source)
    end

    def test_media_type_raises_for_media_no_signature_names
      source = Uploader.const_get(:Source).for(StringIO.new("not media at all"))
      error = assert_raises(InvalidMediaType) { Uploader.const_get(:Signature).media_type!(source) }

      assert_equal "unable to determine the media type of the media given: pass media_category", error.message
    end
  end
end
