# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaChunkedTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload"
    TEST_BOUNDARY = "AaB03x"
    VIDEO_FILE = "test/sample_files/sample.mp4"
    VIDEO_MIME_TYPE = "video/mp4"

    def setup
      @client = Client.new
      @video_size = File.size(VIDEO_FILE)
    end

    def test_chunked_upload_initializes_appends_and_finalizes
      stub_chunked_upload_workflow
      response = perform_chunked_upload

      assert_equal TEST_MEDIA_ID.to_i, response["id"]
    end

    def test_chunked_upload_returns_nil_when_finalize_returns_empty_response
      stub_chunked_upload_workflow(finalize_status: 204, finalize_body: nil)

      assert_nil perform_chunked_upload
    end

    def test_init_raises_when_server_returns_empty_response
      stub_request(:post, init_url).to_return(status: 204)

      assert_raises(MissingData) { init }
    end

    def test_init_raises_when_server_returns_a_response_without_data
      stub_request(:post, init_url).to_return(status: 202, headers: json_headers, body: "{}")

      assert_raises(MissingData) { init }
    end

    def test_chunked_upload_raises_before_a_chunk_is_uploaded_when_init_returns_no_media
      stub_request(:post, init_url).to_return(status: 204)
      append = stub_append_request

      assert_raises(MissingData) { perform_chunked_upload }
      assert_not_requested append
    end

    def test_append_uploads_chunks_with_segment_indices
      stub_append_request

      append(chunk_size: @video_size - 1)
      bodies = collect_request_bodies(:post, append_url, expected_count: 2)

      2.times { |i| assert_segment_in_bodies(bodies, i) }
    end

    def test_append_does_not_report_exceptions_on_stderr
      stub_request(:post, append_url).to_return(status: 401)

      _, err = capture_subprocess_io do
        assert_raises(Unauthorized) { append(chunk_size: @video_size) }
      end

      assert_empty err
    end

    def test_append_leaves_global_exception_reporting_alone
      stub_append_request
      previous = Thread.report_on_exception
      Thread.report_on_exception = true
      append(chunk_size: @video_size)

      assert Thread.report_on_exception
    ensure
      Thread.report_on_exception = previous
    end

    private

    def append(chunk_size:)
      Uploader.const_get(:Chunks).append(client: @client, source: video_source, chunk_size:, media: media_hash, boundary: TEST_BOUNDARY, concurrency: 4)
    end

    def init
      Uploader.const_get(:Chunks).init(client: @client, source: video_source, media_type: VIDEO_MIME_TYPE,
        media_category: Uploader::MediaUpload::TWEET_VIDEO)
    end

    def video_source = Uploader.const_get(:Source).for(VIDEO_FILE)

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
      chunk_size_mb = (@video_size - 1) / Uploader::MediaUpload::BYTES_PER_MB.to_f
      Uploader::MediaUpload.chunked_upload(VIDEO_FILE, client: @client,
        media_category: Uploader::MediaUpload::TWEET_VIDEO, chunk_size_mb:)
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
