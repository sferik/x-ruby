require "tmpdir"
require_relative "../../test_helper"
require "x/media/media_uploader"

module X
  class MediaUploaderSegmentsTest < Minitest::Test
    cover MediaUploader

    BASE_URL = "https://api.twitter.com/2/media/upload".freeze
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    BOUNDARY = "AaB03x".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze
    CHUNK_BYTES = 65_536
    HEX_BOUNDARY = %r{\Amultipart/form-data; boundary=(\h{32})\z}

    def setup
      @client = Client.new
      @appends = Queue.new
      stub_workflow
    end

    def test_segments_carry_their_index_and_exact_content
      upload(VIDEO_FILE, boundary: BOUNDARY, chunk_size_mb: chunk_size_mb)
      content = File.binread(VIDEO_FILE)

      assert_equal [segment_body(0, content.byteslice(0, CHUNK_BYTES), BOUNDARY),
        segment_body(1, content.byteslice(CHUNK_BYTES..), BOUNDARY)], append_bodies
    end

    def test_segments_use_the_boundary_in_their_headers
      upload(VIDEO_FILE, boundary: BOUNDARY, chunk_size_mb: chunk_size_mb)

      assert_equal ["multipart/form-data; boundary=#{BOUNDARY}"] * 2, append_requests.map { |request| request.headers["Content-Type"] }
    end

    def test_default_boundary
      upload(VIDEO_FILE, chunk_size_mb: chunk_size_mb)
      request = append_requests.first
      boundary = HEX_BOUNDARY.match(request.headers["Content-Type"])[1]

      assert_equal segment_body(0, File.binread(VIDEO_FILE, CHUNK_BYTES), boundary), request.body.b
    end

    def test_file_that_fills_its_last_chunk_exactly
      with_file(2 * CHUNK_BYTES) { |path| upload(path, chunk_size_mb:) }

      assert_equal 2, append_requests.size
    end

    def test_default_chunk_size_is_one_megabyte
      with_file(MediaUploader::BYTES_PER_MB + 1) { |path| upload(path) }

      assert_equal 2, append_requests.size
    end

    def test_chunk_size_scales_with_megabytes
      with_file((2 * MediaUploader::BYTES_PER_MB) + 1) { |path| upload(path, chunk_size_mb: 2) }

      assert_equal 2, append_requests.size
    end

    private

    def chunk_size_mb = CHUNK_BYTES / MediaUploader::BYTES_PER_MB.to_f

    def upload(file_path, **)
      MediaUploader.chunked_upload(client: @client, file_path:, media_category: "tweet_video", **)
    end

    def with_file(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.binwrite(path, "\x01".b * size)
        yield path
      end
    end

    def append_requests
      Array.new(@appends.size) { @appends.pop }.sort_by { |request| request.body.b[/name="segment_index"\r\n\r\n(\d+)/, 1].to_i }
    end

    def append_bodies
      append_requests.map { |request| request.body.b }
    end

    def segment_body(index, content, boundary)
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"segment_index\"\r\n\r\n#{index}\r\n" \
        "--#{boundary}\r\nContent-Disposition: form-data; name=\"media\"\r\n" \
        "Content-Type: application/octet-stream\r\n\r\n#{content}\r\n--#{boundary}--\r\n".b
    end

    def stub_workflow
      json = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      stub_request(:post, "#{BASE_URL}/initialize").to_return(json)
      stub_request(:post, APPEND_URL).to_return do |request|
        @appends << request
        {status: 204}
      end
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(json)
    end
  end
end
