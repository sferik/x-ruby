require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderTest < Minitest::Test
    cover MediaUploader

    UPLOAD_URL = "https://api.twitter.com/2/media/upload".freeze
    TEST_BOUNDARY = "AaB03x".freeze
    SAMPLE_BINARY_CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze

    def setup
      @client = Client.new
    end

    def test_upload_sends_multipart_request_with_media_category
      stub_upload_request
      response = upload_file("test/sample_files/sample.jpg")

      assert_requested(:post, UPLOAD_URL) do |request|
        assert_includes request.body, multipart_field("media_category", MediaUploader::TWEET_IMAGE)
      end
      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_upload_handles_non_ascii_filename
      stub_upload_request
      response = upload_file("test/sample_files/sample_éè.png")

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_upload_binary_sends_content_directly
      stub_upload_request
      response = MediaUploader.upload_binary(
        client: @client,
        content: SAMPLE_BINARY_CONTENT,
        media_category: MediaUploader::TWEET_IMAGE,
        boundary: TEST_BOUNDARY
      )

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_upload_binary_returns_nil_for_empty_response
      stub_request(:post, UPLOAD_URL).to_return(status: 204)

      response = MediaUploader.upload_binary(
        client: @client,
        content: SAMPLE_BINARY_CONTENT,
        media_category: MediaUploader::TWEET_IMAGE,
        boundary: TEST_BOUNDARY
      )

      assert_nil response
    end

    def test_infer_media_type_returns_correct_mime_type_for_each_category
      mime_type_expectations.each do |(category, expected_mime), file_path|
        actual = MediaUploader.infer_media_type(file_path, category)

        assert_equal expected_mime, actual, "Expected #{expected_mime} for #{category} with #{file_path}"
      end
    end

    def test_infer_media_type_raises_for_unknown_extension
      assert_raises(X::InvalidMediaType) do
        MediaUploader.infer_media_type("test/sample_files/sample.unknown", MediaUploader::TWEET_IMAGE)
      end
    end

    def test_infer_media_type_error_message_includes_file_path
      error = assert_raises(X::InvalidMediaType) do
        MediaUploader.infer_media_type("/tmp/tempfile123", MediaUploader::TWEET_IMAGE)
      end

      assert_includes error.message, "/tmp/tempfile123"
    end

    private

    def stub_upload_request
      stub_request(:post, UPLOAD_URL).to_return(
        body: {data: {id: TEST_MEDIA_ID}}.to_json,
        headers: {"content-type" => "application/json"}
      )
    end

    def upload_file(file_path)
      MediaUploader.upload(
        client: @client,
        file_path: file_path,
        media_category: MediaUploader::TWEET_IMAGE,
        boundary: TEST_BOUNDARY
      )
    end

    def multipart_field(name, value)
      "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}"
    end

    def mime_type_expectations
      {
        %w[tweet_gif image/gif] => "test/sample_files/sample.gif",
        %w[tweet_image image/jpeg] => "test/sample_files/sample.jpg",
        %w[tweet_video video/mp4] => "test/sample_files/sample.mp4",
        %w[tweet_image image/png] => "test/sample_files/sample.png",
        %w[subtitles application/x-subrip] => "test/sample_files/sample.srt",
        %w[tweet_image image/webp] => "test/sample_files/sample.webp"
      }
    end
  end
end
