require_relative "../test_helper"
require_relative "../../lib/x/media_upload"

module X
  # Tests for X::MediaUpload module
  class MediaUploadTest < Minitest::Test
    cover Client

    def setup
      @client = client
      @media = {"media_id" => TEST_MEDIA_ID}
    end

    def test_gif_upload
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?media_category=dm_gif")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      response = MediaUpload.media_upload(client: @client, file_path: "test/sample_files/sample.gif",
        media_category: MediaUpload::DM_GIF)

      assert_equal TEST_MEDIA_ID, response["media_id"]
    end

    def test_jpg_upload
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?media_category=tweet_image")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      response = MediaUpload.media_upload(client: @client, file_path: "test/sample_files/sample.jpg",
        media_category: MediaUpload::TWEET_IMAGE)

      assert_equal TEST_MEDIA_ID, response["media_id"]
    end

    def test_srt_upload
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?media_category=subtitles")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      response = MediaUpload.media_upload(client: @client, file_path: "test/sample_files/sample.srt",
        media_category: MediaUpload::SUBTITLES)

      assert_equal TEST_MEDIA_ID, response["media_id"]
    end

    def test_webp_upload
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?media_category=dm_image")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      response = MediaUpload.media_upload(client: @client, file_path: "test/sample_files/sample.webp",
        media_category: MediaUpload::DM_IMAGE)

      assert_equal TEST_MEDIA_ID, response["media_id"]
    end

    def test_chunked_media_upload
      file_path = "test/sample_files/sample.mp4"
      total_bytes = File.size(file_path)
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=INIT&media_category=tweet_video&media_type=video/mp4&total_bytes=#{total_bytes}")
        .to_return(status: 202, headers: {"content-type" => "application/json"}, body: @media.to_json)
      2.times { |segment_index| stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=APPEND&media_id=1234567890&segment_index=#{segment_index}").to_return(status: 204) }
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=FINALIZE&media_id=#{TEST_MEDIA_ID}")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      response = MediaUpload.chunked_media_upload(client: @client, file_path: file_path,
        media_category: MediaUpload::TWEET_VIDEO, chunk_size_mb: (total_bytes - 1) / MediaUpload::BYTES_PER_MB.to_f)

      assert_equal TEST_MEDIA_ID, response["media_id"]
    end

    def test_await_processing
      stub_request(:get, "https://upload.twitter.com/1.1/media/upload.json?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return({headers: {"content-type" => "application/json"}, body: '{"processing_info": {"state": "pending"}}'},
          {headers: {"content-type" => "application/json"}, body: '{"processing_info": {"state": "succeeded"}}'})

      status = MediaUpload.await_processing(client: @client, media: @media)

      assert_equal "succeeded", status["processing_info"]["state"]
    end

    def test_invalid_media_category
      assert_raises ArgumentError do
        MediaUpload.media_upload(client: @client, file_path: "test/sample_files/sample.png", media_category: "bad")
      end
    end

    def test_retry
      file_path = "test/sample_files/sample.mp4"
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=INIT&media_category=tweet_video&media_type=video/mp4&total_bytes=#{File.size(file_path)}")
        .to_return(status: 202, headers: {"content-type" => "application/json"}, body: @media.to_json)
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=APPEND&media_id=1234567890&segment_index=0")
        .to_return({status: 500}, {status: 204})
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json?command=FINALIZE&media_id=#{TEST_MEDIA_ID}")
        .to_return(status: 201, headers: {"content-type" => "application/json"}, body: @media.to_json)

      assert MediaUpload.chunked_media_upload(client: @client, file_path: file_path,
        media_category: MediaUpload::TWEET_VIDEO)
    end
  end
end
