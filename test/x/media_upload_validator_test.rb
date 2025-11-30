require_relative "../test_helper"
require_relative "../../lib/x/media_upload_validator"

module X
  class MediaUploadValidatorTest < Minitest::Test
    cover MediaUploadValidator

    def test_validate_file_path
      valid_file_path = "test/sample_files/sample.jpg"
      invalid_file_path = "bad/path"

      assert_nil MediaUploadValidator.validate_file_path!(file_path: valid_file_path)
      assert_raises(RuntimeError) { MediaUploadValidator.validate_file_path!(file_path: invalid_file_path) }
    end

    def test_validate_media_category
      valid_category = "tweet_image"
      invalid_category = "invalid_category"

      assert_nil MediaUploadValidator.validate_media_category!(media_category: valid_category)
      assert_raises(ArgumentError) { MediaUploadValidator.validate_media_category!(media_category: invalid_category) }
    end
  end
end
