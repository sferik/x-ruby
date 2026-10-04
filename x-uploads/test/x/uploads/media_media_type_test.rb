# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  class MediaMediaTypeTest < Minitest::Test
    cover Uploads::MediaUpload

    def test_gif_categories
      assert_equal "image/gif", inference.infer_media_type("a.gif", "tweet_gif")
      assert_equal "image/gif", inference.infer_media_type("a.gif", "dm_gif")
    end

    def test_gif_categories_refuse_media_of_no_known_type
      %w[tweet_gif dm_gif].each do |category|
        error = assert_raises(InvalidMediaType) { inference.infer_media_type("a.bin", category) }

        assert_equal "unable to determine the MIME type of a.bin", error.message
      end
    end

    def test_image_categories
      assert_equal "image/jpeg", inference.infer_media_type("a.bin", "tweet_image")
      assert_equal "image/jpeg", inference.infer_media_type("a.bin", "dm_image")
    end

    def test_video_categories
      assert_equal "video/mp4", inference.infer_media_type("a.bin", "tweet_video")
      assert_equal "video/mp4", inference.infer_media_type("a.bin", "dm_video")
    end

    def test_subtitles_category
      assert_equal "text/srt", inference.infer_media_type("a.bin", "subtitles")
    end

    def test_categories_ignore_case
      assert_equal "image/gif", inference.infer_media_type("a.gif", "TWEET_GIF")
      assert_equal "video/mp4", inference.infer_media_type("a.bin", "Dm_Video")
      assert_equal "text/srt", inference.infer_media_type("a.bin", "SUBTITLES")
    end

    def test_a_category_of_a_symbol
      assert_equal %w[image/gif video/mp4], [inference.infer_media_type("a.gif", :tweet_gif), inference.infer_media_type("a.bin", :TWEET_VIDEO)]
    end

    def test_image_categories_use_the_extension
      assert_equal "image/png", inference.infer_media_type("a.png", "tweet_image")
      assert_equal "image/jpeg", inference.infer_media_type("a.jpeg", "dm_image")
    end

    def test_extensions_ignore_case
      assert_equal "image/png", inference.infer_media_type("A.PNG", "tweet_image")
    end

    def test_video_categories_take_every_video_type
      assert_equal %w[video/webm video/quicktime video/quicktime video/mp2t video/mp2t video/mp2t],
        [%w[a.webm tweet_video], %w[a.MOV dm_video], %w[a.qt amplify_video], %w[a.ts tweet_video], %w[a.m2ts tweet_video],
          %w[a.mts tweet_video]].map { |file, category| inference.infer_media_type(file, category) }
    end

    def test_an_m4v_video_uploads_as_mp4
      assert_equal "video/mp4", inference.infer_media_type("a.m4v", "tweet_video")
    end

    def test_subtitles_category_takes_webvtt
      assert_equal "text/vtt", inference.infer_media_type("a.vtt", "subtitles")
    end

    def test_categories_refuse_a_type_they_do_not_take
      [%w[a.mp4 dm_gif], %w[a.mp4 subtitles], %w[a.vtt tweet_video], %w[a.png tweet_video], %w[a.mp4 tweet_image],
        %w[a.srt dm_image]].each do |file, category|
        error = assert_raises(InvalidMediaType) { inference.infer_media_type(file, category) }
        type = Uploads::MediaUpload.const_get(:MIME_TYPE_MAP).fetch(file.delete_prefix("a."))

        assert_equal "#{file} is #{type}, which #{category} media is not: pass the media_category of what it is, or the " \
          "media_type to send it as to chunked_upload", error.message
      end
    end

    def test_image_categories_take_every_image_type
      assert_equal %w[image/bmp image/tiff image/tiff image/pjpeg image/pjpeg image/webp],
        %w[a.bmp a.tif a.tiff a.pjpeg a.pjp a.webp].map { |file| inference.infer_media_type(file, "tweet_image") }
    end

    def test_a_3d_model_is_refused_as_no_category_takes_it
      {"a.glb" => "glTF", "a.USDZ" => "USDZ"}.each do |file, format|
        message = "no media category the API documents takes a #{format} 3D model, such as #{file}"

        assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_category(file) }.message
        assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_type(file, "tweet_image") }.message
      end
    end

    def test_every_documented_type_has_an_extension
      assert_equal Uploads::MediaUpload.const_get(:MIME_TYPES).sort, Uploads::MediaUpload.const_get(:MIME_TYPE_MAP).values.uniq.sort
    end

    def test_infer_media_category_of_every_video_and_subtitles_type
      category = inference.method(:infer_media_category)

      assert_equal %w[tweet_video] * 7, %w[a.mp4 a.mov a.qt a.webm a.ts a.m2ts a.mts].map(&category)
      assert_equal "tweet_video", category.call("a.m4v")
      assert_equal %w[subtitles subtitles], %w[a.srt a.VTT].map(&category)
      assert_equal %w[tweet_image] * 2, %w[a.bmp a.tiff].map(&category)
    end

    def test_unknown_extension_message
      error = assert_raises(InvalidMediaType) { inference.infer_media_type("/tmp/tempfile123", "tweet_gif") }

      assert_equal "unable to determine the MIME type of /tmp/tempfile123", error.message
    end

    def test_unknown_extension_message_of_a_pathname
      error = assert_raises(InvalidMediaType) { inference.infer_media_type(Pathname("/tmp/tempfile123"), "tweet_gif") }

      assert_equal "unable to determine the MIME type of /tmp/tempfile123", error.message
    end
  end
end
