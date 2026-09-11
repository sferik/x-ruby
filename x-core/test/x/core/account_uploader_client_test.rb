require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/core/account_uploader"

module X
  class AccountUploaderClientTest < Minitest::Test
    cover AccountUploader

    V1_URL = "https://api.x.com/1.1/account/".freeze
    V1_URL_PATTERN = /\A#{Regexp.escape(V1_URL)}/

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, V1_URL_PATTERN).to_return(status: 200)
    end

    def test_image_upload_uses_a_v1_client_with_the_same_credentials
      arguments = capture_client_arguments do
        AccountUploader.upload_profile_image_binary(client: @client, content: "image")
      end

      assert_equal expected_client_arguments, arguments
    end

    def test_banner_upload_uses_a_v1_client_with_the_same_credentials
      arguments = capture_client_arguments do
        AccountUploader.upload_profile_banner_binary(client: @client, content: "banner")
      end

      assert_equal expected_client_arguments, arguments
    end

    def test_missing_file_message
      error = assert_raises(RuntimeError) { AccountUploader.update_profile_image(client: @client, file_path: "nope.png") }

      assert_equal "File not found: nope.png", error.message
    end

    def test_unsupported_file_type_message
      error = assert_raises(InvalidMediaType) do
        AccountUploader.update_profile_banner(client: @client, file_path: "test/sample_files/sample.mp4")
      end

      assert_equal "Unsupported file type: mp4. Supported types: gif, jpg, jpeg, png", error.message
    end

    def test_extension_is_case_insensitive
      Dir.mktmpdir do |dir|
        path = File.join(dir, "AVATAR.PNG")
        FileUtils.cp("test/sample_files/sample.png", path)
        AccountUploader.update_profile_image(client: @client, file_path: path)
      end

      assert_requested(:post, "#{V1_URL}update_profile_image.json")
    end

    private

    def expected_client_arguments
      {api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, access_token: TEST_ACCESS_TOKEN,
       access_token_secret: TEST_ACCESS_TOKEN_SECRET, base_url: AccountUploader::V1_BASE_URL}
    end

    def capture_client_arguments(&)
      arguments = nil
      original = Client.method(:new)
      Client.stub(:new, lambda { |**kwargs|
        arguments = kwargs
        original.call(**kwargs)
      }, &)
      arguments
    end
  end
end
