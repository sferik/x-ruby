require_relative "../../test_helper"
require "x/core/media_upload_validator"

module X
  class MediaUploadValidatorTest < Minitest::Test
    cover MediaUploadValidator

    def test_validate_file_path
      assert_nil MediaUploadValidator.validate_file_path!(file_path: "test/sample_files/sample.jpg")
    end

    def test_validate_file_path_raises_for_missing_file
      error = assert_raises(RuntimeError) { MediaUploadValidator.validate_file_path!(file_path: "bad/path") }

      assert_equal "File not found: bad/path", error.message
    end

    def test_validate_media_category
      assert_nil MediaUploadValidator.validate_media_category!(media_category: "tweet_image")
    end

    def test_validate_media_category_ignores_case
      assert_nil MediaUploadValidator.validate_media_category!(media_category: "TWEET_IMAGE")
    end

    def test_validate_media_category_raises_for_invalid_category
      error = assert_raises(ArgumentError) { MediaUploadValidator.validate_media_category!(media_category: "bogus") }

      assert_equal "Invalid media_category: bogus. Valid values: dm_gif, dm_image, dm_video, subtitles, tweet_gif, " \
        "tweet_image, tweet_video", error.message
    end
  end
end
