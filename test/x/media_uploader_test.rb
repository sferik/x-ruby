require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderTest < Minitest::Test
    cover MediaUploader

    def setup
      @client = Client.new
      @media = {"id" => TEST_MEDIA_ID}
      @data = {"data" => @media}
    end

    def test_upload
      file_path = "test/sample_files/sample.jpg"
      stub_request(:post, "https://api.twitter.com/2/media/upload?media_category=#{MediaUploader::TWEET_IMAGE}")
        .to_return(body: @media.to_json, headers: {"Content-Type" => "application/json"})

      result = MediaUploader.upload(client: @client, file_path:, media_category: MediaUploader::TWEET_IMAGE, boundary: "AaB03x")

      assert_equal TEST_MEDIA_ID, result["id"]
    end

    def test_chunked_upload
      file_path = "test/sample_files/sample.mp4"
      total_bytes = File.size(file_path)
      chunk_size_mb = (total_bytes - 1) / MediaUploader::BYTES_PER_MB.to_f
      stub_request(:post, "https://api.twitter.com/2/media/upload?command=INIT&media_category=tweet_video&media_type=video/mp4&total_bytes=#{total_bytes}")
        .to_return(status: 202, headers: {"content-type" => "application/json"}, body: @data.to_json)
      2.times { |segment_index| stub_request(:post, "https://api.twitter.com/2/media/upload?command=APPEND&media_id=#{TEST_MEDIA_ID}&segment_index=#{segment_index}").to_return(status: 204) }
      stub_request(:post, "https://api.twitter.com/2/media/upload?command=FINALIZE&media_id=#{TEST_MEDIA_ID}")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @data.to_json)

      response = MediaUploader.chunked_upload(client: @client, file_path:, media_category: MediaUploader::TWEET_VIDEO, chunk_size_mb:)

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_append_method
      file_path = "test/sample_files/sample.mp4"
      file_paths = MediaUploader.send(:split, file_path, File.size(file_path) - 1)

      file_paths.each_with_index do |_chunk_path, segment_index|
        stub_request(:post, "https://api.twitter.com/2/media/upload?command=APPEND&media_id=#{TEST_MEDIA_ID}&segment_index=#{segment_index}")
          .with(headers: {"Content-Type" => "multipart/form-data, boundary=AaB03x"}).to_return(status: 204)
      end
      MediaUploader.send(:append, client: @client, file_paths:, media: @media, media_type: "video/mp4", boundary: "AaB03x")

      file_paths.each_with_index { |_, segment_index| assert_requested(:post, "https://api.twitter.com/2/media/upload?command=APPEND&media_id=#{TEST_MEDIA_ID}&segment_index=#{segment_index}") }
    end

    def test_await_processing
      stub_request(:get, "https://api.twitter.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: {"content-type" => "application/json"}, body: '{"data":{"processing_info": {"state": "pending"}}}')
        .to_return(headers: {"content-type" => "application/json"}, body: '{"data":{"processing_info": {"state": "succeeded"}}}')
      result = MediaUploader.await_processing(client: @client, media: @media)

      assert_equal "succeeded", result["processing_info"]["state"]
    end

    def test_await_processing_and_failed
      stub_request(:get, "https://api.twitter.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: {"content-type" => "application/json"}, body: '{"data":{"processing_info": {"state": "pending"}}}')
        .to_return(headers: {"content-type" => "application/json"}, body: '{"data":{"processing_info": {"state": "failed"}}}')
      result = MediaUploader.await_processing(client: @client, media: @media)

      assert_equal "failed", result["processing_info"]["state"]
    end

    def test_retry
      file_path = "test/sample_files/sample.mp4"
      stub_request(:post, "https://api.twitter.com/2/media/upload?command=INIT&media_category=tweet_video&media_type=video/mp4&total_bytes=#{File.size(file_path)}")
        .to_return(status: 202, headers: {"content-type" => "application/json"}, body: @data.to_json)
      stub_request(:post, "https://api.twitter.com/2/media/upload?command=APPEND&media_id=#{TEST_MEDIA_ID}&segment_index=0")
        .to_return(status: 500).to_return(status: 204)
      stub_request(:post, "https://api.twitter.com/2/media/upload?command=FINALIZE&media_id=#{TEST_MEDIA_ID}")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @data.to_json)

      assert MediaUploader.chunked_upload(client: @client, file_path:, media_category: MediaUploader::TWEET_VIDEO)
    end

    def test_validate_with_valid_params
      file_path = "test/sample_files/sample.jpg"

      assert_nil MediaUploader.send(:validate!, file_path:, media_category: MediaUploader::TWEET_IMAGE)
    end

    def test_validate_with_invalid_file_path
      file_path = "invalid/file/path"
      assert_raises(RuntimeError) do
        MediaUploader.send(:validate!, file_path:, media_category: MediaUploader::TWEET_IMAGE)
      end
    end

    def test_validate_with_invalid_media_category
      file_path = "test/sample_files/sample.jpg"
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
