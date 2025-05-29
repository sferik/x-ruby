require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderTest < Minitest::Test
    cover MediaUploader
    BOUNDARY = "AaB03x".freeze
    BASE_URL = "https://api.twitter.com/2/media/upload".freeze
    MEDIA = {"id" => TEST_MEDIA_ID}.freeze
    JSON_BODY = {"data" => MEDIA}.to_json.freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_upload
      file_path = "test/sample_files/sample.jpg"
      stub_request(:post, BASE_URL).to_return(body: JSON_BODY, headers: JSON_HEADERS)
      response = MediaUploader.upload(client: @client, file_path:, media_category: MediaUploader::TWEET_IMAGE, boundary: BOUNDARY)

      assert_requested(:post, "https://api.twitter.com/2/media/upload") do |request|
        assert_includes(request.body, "Content-Disposition: form-data; name=\"media_category\"\r\n\r\n#{MediaUploader::TWEET_IMAGE}")
      end

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_chunked_upload
      file_path = "test/sample_files/sample.mp4"
      total_bytes = File.size(file_path)
      chunk_size_mb = (total_bytes - 1) / MediaUploader::BYTES_PER_MB.to_f
      body_json = {media_type: "video/mp4", media_category: "tweet_video", total_bytes:}.to_json
      stub_request(:post, "#{BASE_URL}/initialize").with(body: body_json).to_return(status: 202, headers: JSON_HEADERS, body: JSON_BODY)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(status: 201, headers: JSON_HEADERS, body: JSON_BODY)
      response = MediaUploader.chunked_upload(client: @client, file_path:, media_category: MediaUploader::TWEET_VIDEO, chunk_size_mb:)

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_append_method
      file_path = "test/sample_files/sample.mp4"
      file_paths = MediaUploader.send(:split, file_path, File.size(file_path) - 1)
      headers = {"Content-Type" => "multipart/form-data, boundary=#{BOUNDARY}"}
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").with(headers:).to_return(status: 204)
      MediaUploader.send(:append, client: @client, file_paths:, media: MEDIA, media_type: "video/mp4", boundary: BOUNDARY)

      bodies = []
      assert_requested(:post, "https://api.twitter.com/2/media/upload/#{TEST_MEDIA_ID}/append", times: 2) { |request| bodies << request.body }

      file_paths.each_index do |segment_index|
        assert(bodies.one? { |body| body.include?("Content-Disposition: form-data; name=\"segment_index\"\r\n\r\n#{segment_index}\r\n") })
      end
    end

    def test_await_processing
      stub_request(:get, "https://api.twitter.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: JSON_HEADERS, body: '{"data":{"processing_info": {"state": "pending"}}}')
        .to_return(headers: JSON_HEADERS, body: '{"data":{"processing_info": {"state": "succeeded"}}}')
      response = MediaUploader.await_processing(client: @client, media: MEDIA)

      assert_equal "succeeded", response["processing_info"]["state"]
    end

    def test_await_processing_failed
      stub_request(:get, "https://api.twitter.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: JSON_HEADERS, body: '{"data":{"processing_info": {"state": "pending"}}}')
        .to_return(headers: JSON_HEADERS, body: '{"data":{"processing_info": {"state": "failed"}}}')
      response = MediaUploader.await_processing(client: @client, media: MEDIA)

      assert_equal "failed", response["processing_info"]["state"]
    end

    def test_retry
      file_path = "test/sample_files/sample.mp4"
      body_json = {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size(file_path)}.to_json
      stub_request(:post, "#{BASE_URL}/initialize").with(body: body_json).to_return(status: 202, headers: JSON_HEADERS, body: JSON_BODY)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 500).to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(status: 201, headers: JSON_HEADERS, body: JSON_BODY)

      assert MediaUploader.chunked_upload(client: @client, file_path:, media_category: MediaUploader::TWEET_VIDEO)
    end

    def test_validate
      file_path = "test/sample_files/sample.jpg"

      assert_nil MediaUploader.send(:validate!, file_path:, media_category: MediaUploader::TWEET_IMAGE)
      assert_raises(RuntimeError) do
        MediaUploader.send(:validate!, file_path: "bad/path", media_category: MediaUploader::TWEET_IMAGE)
      end
      assert_raises(ArgumentError) do
        MediaUploader.send(:validate!, file_path:, media_category: "invalid_category")
      end
    end

    def test_infer_media_type_for_gif
      assert_equal MediaUploader::GIF_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.gif", "tweet_gif")
    end

    def test_infer_media_type_for_jpg
      assert_equal MediaUploader::JPEG_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.jpg", "tweet_image")
    end

    def test_infer_media_type_for_mp4
      assert_equal MediaUploader::MP4_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.mp4", "tweet_video")
    end

    def test_infer_media_type_for_png
      assert_equal MediaUploader::PNG_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.png", "tweet_image")
    end

    def test_infer_media_type_for_srt
      assert_equal MediaUploader::SUBRIP_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.srt", "subtitles")
    end

    def test_infer_media_type_for_webp
      assert_equal MediaUploader::WEBP_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.webp", "tweet_image")
    end

    def test_infer_media_type_with_default
      assert_equal MediaUploader::DEFAULT_MIME_TYPE, MediaUploader.send(:infer_media_type, "test/sample_files/sample.dne", "tweet_image")
    end
  end
end
