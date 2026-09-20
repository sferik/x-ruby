require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaChunkSizeTest < Minitest::Test
    cover Uploader::Media

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    # A video larger than the 1,000 chunks of a megabyte the API numbers the segments of
    LARGE_VIDEO_BYTES = 1100 * Uploader::Media::BYTES_PER_MB

    def setup
      @client = Client.new
      stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def test_a_video_larger_than_a_thousand_megabytes_uploads_in_the_segments_the_api_numbers
      chunk_size = with_large_video { |path| upload(path) }

      assert_equal 1_153_434, chunk_size
      assert_operator (LARGE_VIDEO_BYTES.to_f / chunk_size).ceil, :<=, 1000
    end

    def test_a_video_of_a_megabyte_uploads_in_chunks_of_a_megabyte
      chunk_size = with_video(Uploader::Media::BYTES_PER_MB) { |path| upload(path) }

      assert_equal Uploader::Media::BYTES_PER_MB, chunk_size
    end

    def test_a_chunk_size_given_is_taken_whole_megabytes_or_not
      assert_equal [2_097_152, 524_288], [2, 0.5].map { |mb| with_video(Uploader::Media::BYTES_PER_MB) { |path| upload(path, chunk_size_mb: mb) } }
    end

    def test_a_chunk_size_that_would_need_more_segments_than_the_api_numbers_uploads_nothing
      error = assert_raises(ArgumentError) { with_large_video { |path| upload(path, chunk_size_mb: 1) } }

      assert_equal "chunk_size_mb of 1 uploads #{LARGE_VIDEO_BYTES} bytes in more than the 1000 segments the API numbers", error.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunked_upload_of_its_own_rejects_chunk_options_the_api_would_refuse
      size = assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", chunk_size_mb: 0) }
      concurrency = assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", concurrency: 0) }

      assert_equal "chunk_size_mb must be positive, not 0", size.message
      assert_equal "concurrency must be an Integer of at least 1, not 0", concurrency.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunked_upload_of_its_own_rejects_a_chunk_size_that_would_need_more_segments
      assert_raises(ArgumentError) { with_large_video { |path| chunked_upload(path, chunk_size_mb: 1) } }
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    private

    def chunked_upload(file_path, **)
      Uploader::Media.chunked_upload(file_path, client: @client, media_category: "tweet_video", **)
    end

    # The size of the chunks the upload of the block would have appended, which it appends none of
    def upload(file_path, **)
      chunk_size = nil
      Uploader.const_get(:Chunks).stub(:append, ->(**options) { chunk_size = options.fetch(:chunk_size) }) do
        Uploader::Media.upload(file_path, client: @client, media_category: "tweet_video", media_type: "video/mp4", **)
      end
      chunk_size
    end

    def with_large_video(&) = with_video(LARGE_VIDEO_BYTES, &)

    # A sparse file of a size, which costs no disk of its own
    def with_video(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.write(path, "")
        File.truncate(path, size)
        yield path
      end
    end
  end
end
