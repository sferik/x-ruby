require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderChunkedTest < Minitest::Test
    cover MediaUploader

    BASE_URL = "https://api.twitter.com/2/media/upload".freeze
    TEST_BOUNDARY = "AaB03x".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze
    VIDEO_MIME_TYPE = "video/mp4".freeze

    def setup
      @client = Client.new
      @video_size = File.size(VIDEO_FILE)
    end

    def test_chunked_upload_initializes_appends_and_finalizes
      stub_chunked_upload_workflow
      response = perform_chunked_upload

      assert_equal TEST_MEDIA_ID, response["id"]
    end

    def test_chunked_upload_returns_nil_when_finalize_returns_empty_response
      stub_chunked_upload_workflow(finalize_status: 204, finalize_body: nil)

      assert_nil perform_chunked_upload
    end

    def test_init_returns_nil_when_server_returns_empty_response
      stub_request(:post, init_url).to_return(status: 204)

      response = MediaUploader.send(:init, client: @client, file_path: VIDEO_FILE,
        media_type: VIDEO_MIME_TYPE, media_category: MediaUploader::TWEET_VIDEO)

      assert_nil response
    end

    def test_append_uploads_chunks_with_segment_indices
      chunk_paths = MediaUploader.send(:split, VIDEO_FILE, @video_size - 1)
      stub_append_request

      MediaUploader.send(:append, client: @client, file_paths: chunk_paths, media: media_hash, boundary: TEST_BOUNDARY)
      bodies = collect_request_bodies(:post, append_url, expected_count: 2)

      chunk_paths.each_index { |i| assert_segment_in_bodies(bodies, i) }
    end

    private

    def media_hash = {"id" => TEST_MEDIA_ID}
    def json_headers = {"content-type" => "application/json"}
    def init_url = "#{BASE_URL}/initialize"
    def append_url = "#{BASE_URL}/#{TEST_MEDIA_ID}/append"
    def finalize_url = "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize"

    def stub_init_request
      body = {media_type: VIDEO_MIME_TYPE, media_category: "tweet_video", total_bytes: @video_size}.to_json
      stub_request(:post, init_url).with(body:).to_return(status: 202, headers: json_headers, body: {data: media_hash}.to_json)
    end

    def stub_append_request
      stub_request(:post, append_url)
        .with(headers: {"Content-Type" => "multipart/form-data; boundary=#{TEST_BOUNDARY}"})
        .to_return(status: 204)
    end

    def stub_finalize_request(status: 201, body: {data: media_hash}.to_json)
      stub_request(:post, finalize_url).to_return(status:, headers: json_headers, body:)
    end

    def stub_chunked_upload_workflow(finalize_status: 201, finalize_body: {data: media_hash}.to_json)
      stub_init_request
      stub_request(:post, append_url).to_return(status: 204)
      stub_finalize_request(status: finalize_status, body: finalize_body)
    end

    def perform_chunked_upload
      chunk_size_mb = (@video_size - 1) / MediaUploader::BYTES_PER_MB.to_f
      MediaUploader.chunked_upload(client: @client, file_path: VIDEO_FILE,
        media_category: MediaUploader::TWEET_VIDEO, chunk_size_mb:)
    end

    def collect_request_bodies(method, url, expected_count:)
      bodies = []
      assert_requested(method, url, times: expected_count) { |req| bodies << req.body }
      bodies
    end

    def assert_segment_in_bodies(bodies, segment_index)
      field = "Content-Disposition: form-data; name=\"segment_index\"\r\n\r\n#{segment_index}\r\n"

      assert bodies.one? { |body| body.include?(field) }, "Expected segment_index #{segment_index}"
    end
  end
end
