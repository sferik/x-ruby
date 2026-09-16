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

    def test_image_categories_use_the_extension
      assert_equal "image/png", Uploader::Media.infer_media_type("a.png", "tweet_image")
      assert_equal "image/jpeg", Uploader::Media.infer_media_type("a.jpeg", "dm_image")
    end

    def test_extensions_ignore_case
      assert_equal "image/png", Uploader::Media.infer_media_type("A.PNG", "tweet_image")
    end

    def test_unknown_extension_message
      error = assert_raises(Uploader::InvalidMediaType) { Uploader::Media.infer_media_type("/tmp/tempfile123", "tweet_image") }

      assert_equal 'unable to determine MIME type from file extension: "/tmp/tempfile123"', error.message
    end
  end
end
