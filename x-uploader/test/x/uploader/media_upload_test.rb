require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaUploadTest < Minitest::Test
    cover Uploader::Media
    cover Uploader::Chunks

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_infer_media_category
      assert_equal "tweet_gif", Uploader::Media.infer_media_category("a.gif")
      assert_equal "tweet_video", Uploader::Media.infer_media_category("a.mp4")
      assert_equal "subtitles", Uploader::Media.infer_media_category("a.srt")
      assert_equal "tweet_image", Uploader::Media.infer_media_category("a.png")
      assert_equal "tweet_image", Uploader::Media.infer_media_category("a.jpeg")
    end

    def test_infer_media_category_ignores_case_and_unknown_extensions
      assert_equal "tweet_gif", Uploader::Media.infer_media_category("A.GIF")
      assert_equal "tweet_image", Uploader::Media.infer_media_category("a.unknown")
      assert_equal "tweet_image", Uploader::Media.infer_media_category("a")
    end

    def test_infer_media_category_tells_a_still_gif_from_an_animated_one
      assert_equal "tweet_image", Uploader::Media.infer_media_category("test/sample_files/sample.gif")
      assert_equal "tweet_gif", Uploader::Media.infer_media_category("test/sample_files/sample_animated.gif")
      assert_equal "tweet_image", Uploader::Media.infer_media_category("test/sample_files/sample.png")
    end

    def test_upload_infers_the_category_from_the_extension
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      response = Uploader::Media.upload("test/sample_files/sample_animated.gif", client: @client)

      assert_equal TEST_MEDIA_ID, response["id"]
      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_gif") }
    end

    def test_upload_uploads_a_video_in_chunks_and_awaits_processing
      stub_chunked_workflow
      response = Uploader::Media.upload("test/sample_files/sample.mp4", client: @client)

      assert_equal TEST_MEDIA_ID, response["id"]
      assert_equal "succeeded", response.dig("processing_info", "state")
      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size("test/sample_files/sample.mp4")}.to_json
      assert_not_requested :post, BASE_URL
    end

    def test_upload_chunks_by_category_rather_than_extension
      stub_chunked_workflow
      Uploader::Media.upload("test/sample_files/sample.png", client: @client, media_category: "DM_VIDEO", media_type: "video/mp4")

      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "video/mp4", media_category: "DM_VIDEO", total_bytes: 68}.to_json
    end

    def test_upload_raises_when_video_processing_fails
      stub_chunked_workflow(state: "failed")

      assert_raises(Uploader::MediaProcessingFailed) { Uploader::Media.upload("test/sample_files/sample.mp4", client: @client) }
    end

    def test_upload_a_still_gif_as_an_image
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploader::Media.upload("test/sample_files/sample.gif", client: @client)

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_image") }
    end

    def test_upload_subtitles_in_chunks_without_awaiting_processing
      stub_chunked_workflow(processing: false)
      response = Uploader::Media.upload("test/sample_files/sample.srt", client: @client)

      assert_equal({"id" => TEST_MEDIA_ID}, response)
      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "text/srt", media_category: "subtitles", total_bytes: 0}.to_json
      assert_not_requested :get, "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}"
    end

    def test_upload_in_chunks_whose_finalize_returns_nothing
      stub_chunked_workflow
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(status: 204)

      assert_nil Uploader::Media.upload("test/sample_files/sample.srt", client: @client)
      assert_not_requested :get, "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}"
    end

    def test_upload_with_alt_text
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "https://api.x.com/2/media/metadata").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      response = Uploader::Media.upload("test/sample_files/sample.png", client: @client, alt_text: "A pixel")

      assert_equal({"id" => TEST_MEDIA_ID}, response)
      assert_requested :post, "https://api.x.com/2/media/metadata", body: {id: TEST_MEDIA_ID, metadata: {alt_text: {text: "A pixel"}}}.to_json
    end

    def test_upload_without_alt_text_sends_no_metadata
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploader::Media.upload("test/sample_files/sample.png", client: @client)

      assert_not_requested :post, "https://api.x.com/2/media/metadata"
    end

    def test_upload_rejects_a_missing_video_before_requesting
      error = assert_raises(Errno::ENOENT) { Uploader::Media.upload("nope.mp4", client: @client) }

      assert_equal "No such file or directory - nope.mp4", error.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    private

    def stub_chunked_workflow(state: "succeeded", processing: true)
      json = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      finalized = {data: {id: TEST_MEDIA_ID, processing_info: ({state: "pending"} if processing)}.compact}
      stub_request(:post, "#{BASE_URL}/initialize").to_return(json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: finalized.to_json)
      stub_request(:get, "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state:}}}.to_json)
    end
  end
end
