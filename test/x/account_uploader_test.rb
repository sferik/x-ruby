require_relative "../test_helper"
require_relative "../../lib/x/account_uploader"

module X
  class AccountUploaderProfileImageTest < Minitest::Test
    cover AccountUploader

    V1_PROFILE_IMAGE_URL = "https://api.x.com/1.1/account/update_profile_image.json".freeze
    TEST_BOUNDARY = "AaB03x".freeze
    SAMPLE_BINARY_CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze

    def setup
      @client = Client.new(**test_oauth_credentials)
    end

    def test_update_profile_image_sends_multipart_request
      stub_profile_image_request
      response = update_profile_image("test/sample_files/sample.png")

      assert_multipart_image_request
      assert_equal "12345", response["id"]
    end

    def test_update_profile_image_binary_sends_content_directly
      stub_profile_image_request
      response = AccountUploader.upload_profile_image_binary(client: @client, content: SAMPLE_BINARY_CONTENT,
        boundary: TEST_BOUNDARY)

      assert_requested(:post, V1_PROFILE_IMAGE_URL)
      assert_equal "12345", response["id"]
    end

    def test_update_profile_image_raises_for_missing_file
      error = assert_raises(RuntimeError) { update_profile_image("nonexistent.png") }

      assert_includes error.message, "File not found"
    end

    def test_update_profile_image_raises_for_unsupported_file_type
      error = assert_raises(X::InvalidMediaType) { update_profile_image("test/sample_files/sample.mp4") }

      assert_includes error.message, "Unsupported file type"
    end

    def test_supports_jpg_extension
      stub_profile_image_request
      update_profile_image("test/sample_files/sample.jpg")

      assert_requested(:post, V1_PROFILE_IMAGE_URL)
    end

    def test_supports_gif_extension
      stub_profile_image_request
      update_profile_image("test/sample_files/sample.gif")

      assert_requested(:post, V1_PROFILE_IMAGE_URL)
    end

    private

    def update_profile_image(file_path)
      AccountUploader.update_profile_image(client: @client, file_path:, boundary: TEST_BOUNDARY)
    end

    def stub_profile_image_request
      stub_request(:post, V1_PROFILE_IMAGE_URL).to_return(
        body: {id: "12345", screen_name: "testuser"}.to_json, headers: {"content-type" => "application/json"}
      )
    end

    def assert_multipart_image_request
      assert_requested(:post, V1_PROFILE_IMAGE_URL) do |request|
        assert_includes request.body, "Content-Disposition: form-data; name=\"image\""
        assert_includes request.headers["Content-Type"], "multipart/form-data"
      end
    end
  end

  class AccountUploaderProfileBannerTest < Minitest::Test
    cover AccountUploader

    V1_PROFILE_BANNER_URL = "https://api.x.com/1.1/account/update_profile_banner.json".freeze
    TEST_BOUNDARY = "AaB03x".freeze
    SAMPLE_BINARY_CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze

    def setup
      @client = Client.new(**test_oauth_credentials)
    end

    def test_update_profile_banner_sends_multipart_request
      stub_profile_banner_request
      update_profile_banner("test/sample_files/sample.png")

      assert_multipart_banner_request
    end

    def test_update_profile_banner_with_dimensions
      stub_profile_banner_request
      update_profile_banner_with_dimensions

      assert_banner_dimensions_in_request
    end

    def test_update_profile_banner_binary_sends_content_directly
      stub_profile_banner_request
      AccountUploader.upload_profile_banner_binary(client: @client, content: SAMPLE_BINARY_CONTENT,
        boundary: TEST_BOUNDARY)

      assert_requested(:post, V1_PROFILE_BANNER_URL)
    end

    def test_update_profile_banner_raises_for_missing_file
      error = assert_raises(RuntimeError) { update_profile_banner("nonexistent.png") }

      assert_includes error.message, "File not found"
    end

    def test_update_profile_banner_raises_for_unsupported_file_type
      error = assert_raises(X::InvalidMediaType) { update_profile_banner("test/sample_files/sample.mp4") }

      assert_includes error.message, "Unsupported file type"
    end

    private

    def update_profile_banner(file_path)
      AccountUploader.update_profile_banner(client: @client, file_path:, boundary: TEST_BOUNDARY)
    end

    def update_profile_banner_with_dimensions
      AccountUploader.update_profile_banner(client: @client, file_path: "test/sample_files/sample.png",
        width: 1500, height: 500, offset_left: 0, offset_top: 0, boundary: TEST_BOUNDARY)
    end

    def stub_profile_banner_request
      stub_request(:post, V1_PROFILE_BANNER_URL).to_return(status: 200)
    end

    def assert_multipart_banner_request
      assert_requested(:post, V1_PROFILE_BANNER_URL) do |request|
        assert_includes request.body, "Content-Disposition: form-data; name=\"banner\""
        assert_includes request.headers["Content-Type"], "multipart/form-data"
      end
    end

    def assert_banner_dimensions_in_request
      assert_requested(:post, V1_PROFILE_BANNER_URL) do |request|
        %w[width height offset_left offset_top].each { |field| assert_includes request.body, "name=\"#{field}\"" }
      end
    end
  end
end
