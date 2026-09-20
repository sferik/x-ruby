require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaSegmentsTest < Minitest::Test
    cover Uploader::Media
    cover Uploader.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze
    CHUNK_BYTES = 65_536
    HEX_BOUNDARY = %r{\Amultipart/form-data; boundary=(\h{32})\z}

    def setup
      @client = Client.new
      @appends = Queue.new
      stub_workflow
    end

    def test_segments_carry_their_index_and_exact_content
      upload(VIDEO_FILE, chunk_size_mb: chunk_size_mb)
      requests = append_requests
      boundary = boundary_of(requests.first)
      content = File.binread(VIDEO_FILE)

      assert_equal [segment_body(0, content.byteslice(0, CHUNK_BYTES), boundary),
        segment_body(1, content.byteslice(CHUNK_BYTES..), boundary)], requests.map { |request| request.body.b }
    end

    def test_segments_share_the_boundary_of_the_upload
      upload(VIDEO_FILE, chunk_size_mb: chunk_size_mb)
      content_types = append_requests.map { |request| request.headers["Content-Type"] }

      assert_match HEX_BOUNDARY, content_types.first
      assert_equal [content_types.first] * 2, content_types
    end

    def test_file_that_fills_its_last_chunk_exactly
      with_file(2 * CHUNK_BYTES) { |path| upload(path, chunk_size_mb:) }

      assert_equal 2, append_requests.size
    end

    def test_default_chunk_size_is_one_megabyte
      with_file(Uploader::Media::BYTES_PER_MB + 1) { |path| upload(path) }

      assert_equal 2, append_requests.size
    end

    def test_chunk_size_scales_with_megabytes
      with_file((2 * Uploader::Media::BYTES_PER_MB) + 1) { |path| upload(path, chunk_size_mb: 2) }

      assert_equal 2, append_requests.size
    end

    private

    def chunk_size_mb = CHUNK_BYTES / Uploader::Media::BYTES_PER_MB.to_f

    def upload(file_path, **)
      Uploader::Media.chunked_upload(file_path, client: @client, media_category: "tweet_video", **)
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

    def boundary_of(request) = HEX_BOUNDARY.match(request.headers["Content-Type"])[1]

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
