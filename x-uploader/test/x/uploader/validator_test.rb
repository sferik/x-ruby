require_relative "../../test_helper"
require "x/uploader/validator"

module X
  class ValidatorTest < Minitest::Test
    cover Uploader::Validator

    def test_validate_file_path
      assert_nil Uploader::Validator.validate_file_path!("test/sample_files/sample.jpg")
    end

    def test_validate_file_path_raises_for_missing_file
      error = assert_raises(Errno::ENOENT) { Uploader::Validator.validate_file_path!("bad/path") }

      assert_equal "No such file or directory - bad/path", error.message
    end

    def test_validate_media_category
      assert_nil Uploader::Validator.validate_media_category!("tweet_image")
    end

    def test_validate_amplify_video
      assert_nil Uploader::Validator.validate_media_category!("amplify_video")
    end

    def test_validate_media_category_ignores_case
      assert_nil Uploader::Validator.validate_media_category!("TWEET_IMAGE")
    end

    def test_validate_media_category_raises_for_invalid_category
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_media_category!("bogus") }

      assert_equal "Invalid media_category: bogus. Valid values: amplify_video, dm_gif, dm_image, dm_video, subtitles, tweet_gif, " \
        "tweet_image, tweet_video", error.message
    end
  end
end
