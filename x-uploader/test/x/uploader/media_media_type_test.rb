# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaMediaTypeTest < Minitest::Test
    cover Uploader::Media

    def test_gif_categories
      assert_equal "image/gif", Uploader::Media.infer_media_type("a.bin", "tweet_gif")
      assert_equal "image/gif", Uploader::Media.infer_media_type("a.bin", "dm_gif")
    end

    def test_video_categories
      assert_equal "video/mp4", Uploader::Media.infer_media_type("a.bin", "tweet_video")
      assert_equal "video/mp4", Uploader::Media.infer_media_type("a.bin", "dm_video")
    end

    def test_subtitles_category
      assert_equal "text/srt", Uploader::Media.infer_media_type("a.bin", "subtitles")
    end

    def test_categories_ignore_case
      assert_equal "image/gif", Uploader::Media.infer_media_type("a.bin", "TWEET_GIF")
      assert_equal "video/mp4", Uploader::Media.infer_media_type("a.bin", "Dm_Video")
      assert_equal "text/srt", Uploader::Media.infer_media_type("a.bin", "SUBTITLES")
    end

    def test_a_category_of_a_symbol
      assert_equal %w[image/gif video/mp4], [:tweet_gif, :TWEET_VIDEO].map { |category| Uploader::Media.infer_media_type("a.bin", category) }
    end

    def test_image_categories_use_the_extension
      assert_equal "image/png", Uploader::Media.infer_media_type("a.png", "tweet_image")
      assert_equal "image/jpeg", Uploader::Media.infer_media_type("a.jpeg", "dm_image")
    end

    def test_extensions_ignore_case
      assert_equal "image/png", Uploader::Media.infer_media_type("A.PNG", "tweet_image")
    end

    def test_video_categories_take_every_video_type
      assert_equal %w[video/webm video/quicktime video/quicktime video/mp2t video/mp2t video/mp2t],
        [%w[a.webm tweet_video], %w[a.MOV dm_video], %w[a.qt amplify_video], %w[a.ts tweet_video], %w[a.m2ts tweet_video],
          %w[a.mts tweet_video]].map { |file, category| Uploader::Media.infer_media_type(file, category) }
    end

    def test_videos_of_other_names_upload_as_mp4
      assert_equal %w[video/mp4] * 3, %w[a.m4v a.avi a.mkv].map { |file| Uploader::Media.infer_media_type(file, "tweet_video") }
    end

    def test_subtitles_category_takes_webvtt
      assert_equal "text/vtt", Uploader::Media.infer_media_type("a.vtt", "subtitles")
    end

    def test_categories_default_a_type_they_do_not_take
      assert_equal %w[image/gif text/srt video/mp4],
        [%w[a.mp4 dm_gif], %w[a.mp4 subtitles], %w[a.vtt tweet_video]].map { |file, category| Uploader::Media.infer_media_type(file, category) }
    end

    def test_image_categories_take_every_image_and_model_type
      assert_equal %w[image/bmp image/tiff image/tiff image/pjpeg image/pjpeg image/webp model/gltf-binary model/vnd.usdz+zip],
        %w[a.bmp a.tif a.tiff a.pjpeg a.pjp a.webp a.glb a.usdz].map { |file| Uploader::Media.infer_media_type(file, "tweet_image") }
    end

    def test_every_documented_type_has_an_extension
      assert_equal Uploader::Media.const_get(:MIME_TYPES).sort, Uploader::Media.const_get(:MIME_TYPE_MAP).values.uniq.sort
    end

    def test_infer_media_category_of_every_video_and_subtitles_type
      assert_equal %w[tweet_video] * 7, %w[a.mp4 a.mov a.qt a.webm a.ts a.m2ts a.mts].map { |file| Uploader::Media.infer_media_category(file) }
      assert_equal %w[tweet_video] * 3, %w[a.m4v a.AVI a.mkv].map { |file| Uploader::Media.infer_media_category(file) }
      assert_equal %w[subtitles subtitles], %w[a.srt a.VTT].map { |file| Uploader::Media.infer_media_category(file) }
      assert_equal %w[tweet_image] * 4, %w[a.bmp a.tiff a.glb a.usdz].map { |file| Uploader::Media.infer_media_category(file) }
    end

    def test_unknown_extension_message
      error = assert_raises(Uploader::InvalidMediaType) { Uploader::Media.infer_media_type("/tmp/tempfile123", "tweet_image") }

      assert_equal 'unable to determine MIME type from file extension: "/tmp/tempfile123"', error.message
    end

    def test_unknown_extension_message_of_a_pathname
      error = assert_raises(Uploader::InvalidMediaType) { Uploader::Media.infer_media_type(Pathname("/tmp/tempfile123"), "tweet_image") }

      assert_equal 'unable to determine MIME type from file extension: "/tmp/tempfile123"', error.message
    end
  end
end
