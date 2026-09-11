require_relative "../test_helper"

module X
  class CompatibilityTest < Minitest::Test
    def test_media_uploader_require_path
      require "x/media_uploader"

      assert_respond_to MediaUploader, :chunked_upload
      assert_equal VERSION, MediaUploader::VERSION
    end

    def test_account_uploader_require_path
      require "x/account_uploader"

      assert_respond_to AccountUploader, :update_profile_image
    end
  end
end
