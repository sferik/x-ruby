require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaTest < Minitest::Test
    cover Uploader::Media

    UPLOAD_URL = "https://api.x.com/2/media/upload".freeze
    SAMPLE_BINARY_CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze

    def setup
      @client = Client.new
    end

    def test_upload_sends_multipart_request_with_media_category
      stub_upload_request
      response = upload_file("test/sample_files/sample.jpg")

      assert_requested(:post, UPLOAD_URL) do |request|
        assert_includes request.body, multipart_field("media_category", Uploader::Media::TWEET_IMAGE)
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
      response = Uploader::Media.upload_binary(
        SAMPLE_BINARY_CONTENT,
        client: @client,
        media_category: Uploader::Media::TWEET_IMAGE
      )

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_upload_binary_refuses_amplify_video_before_a_request
      error = assert_raises(ArgumentError) { Uploader::Media.upload_binary("data", client: @client, media_category: :amplify_video) }

      assert_equal "amplify_video uploads in chunks alone: pass the file to upload or chunked_upload", error.message
      assert_not_requested :post, "https://api.x.com/2/media/upload"
    end

    def test_upload_binary_returns_nil_for_empty_response
      stub_request(:post, UPLOAD_URL).to_return(status: 204)

      response = Uploader::Media.upload_binary(
        SAMPLE_BINARY_CONTENT,
        client: @client,
        media_category: Uploader::Media::TWEET_IMAGE
      )

      assert_nil response
    end

    def test_infer_media_type_returns_correct_mime_type_for_each_category
      mime_type_expectations.each do |(category, expected_mime), file_path|
        actual = Uploader::Media.infer_media_type(file_path, category)

        assert_equal expected_mime, actual, "Expected #{expected_mime} for #{category} with #{file_path}"
      end
    end

    def test_infer_media_type_raises_for_unknown_extension
      assert_raises(Uploader::InvalidMediaType) do
        Uploader::Media.infer_media_type("test/sample_files/sample.unknown", Uploader::Media::TWEET_IMAGE)
      end
    end

    def test_infer_media_type_error_message_includes_file_path
      error = assert_raises(Uploader::InvalidMediaType) do
        Uploader::Media.infer_media_type("/tmp/tempfile123", Uploader::Media::TWEET_IMAGE)
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
      Uploader::Media.upload(
        file_path,
        client: @client,
        media_category: Uploader::Media::TWEET_IMAGE
      )
    end

    def multipart_field(name, value)
      "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}"
    end

    def mime_type_expectations
      {
        %w[tweet_gif image/gif] => "test/sample_files/sample_animated.gif",
        %w[tweet_image image/jpeg] => "test/sample_files/sample.jpg",
        %w[tweet_video video/mp4] => "test/sample_files/sample.mp4",
        %w[tweet_image image/png] => "test/sample_files/sample.png",
        %w[subtitles text/srt] => "test/sample_files/sample.srt",
        %w[tweet_image image/webp] => "test/sample_files/sample.webp",
        %w[amplify_video video/mp4] => "test/sample_files/sample.png"
      }
    end
  end
end
