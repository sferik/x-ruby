# frozen_string_literal: true

require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaChunkSizeTest < Minitest::Test
    cover Uploader::MediaUpload

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    # A video larger than the 10,000 chunks of a megabyte the API numbers the segments of
    LARGE_VIDEO_BYTES = 11_000 * Uploader::MediaUpload.const_get(:BYTES_PER_MB)

    def setup
      @client = Client.new
      stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def test_a_video_larger_than_ten_thousand_megabytes_uploads_in_the_segments_the_api_numbers
      chunk_size = with_large_video { |path| upload(path) }

      assert_equal 1_153_434, chunk_size
      assert_operator (LARGE_VIDEO_BYTES.to_f / chunk_size).ceil, :<=, 10_000
    end

    def test_a_video_of_a_megabyte_uploads_in_chunks_of_a_megabyte
      chunk_size = with_video(Uploader::MediaUpload.const_get(:BYTES_PER_MB)) { |path| upload(path) }

      assert_equal Uploader::MediaUpload.const_get(:BYTES_PER_MB), chunk_size
    end

    def test_a_chunk_size_given_is_taken_as_the_bytes_it_names
      assert_equal [2_097_152, 524_288, 1001], [2_097_152, 524_288, 1001].map { |bytes| with_video(Uploader::MediaUpload.const_get(:BYTES_PER_MB)) { |path| upload(path, chunk_size: bytes) } }
    end

    def test_a_chunk_size_that_would_need_more_segments_than_the_api_numbers_uploads_nothing
      error = assert_raises(ArgumentError) { with_large_video { |path| upload(path, chunk_size: 1_048_576) } }

      assert_equal "chunk_size of 1048576 bytes uploads #{LARGE_VIDEO_BYTES} bytes in more than the 10000 segments the API numbers", error.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunked_upload_of_its_own_rejects_chunk_options_the_api_would_refuse
      size = assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", chunk_size: 0) }
      concurrency = assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", concurrency: 0) }

      assert_equal "chunk_size must be a positive Integer of bytes, not 0", size.message
      assert_equal "concurrency must be an Integer of 1 to 16, not 0", concurrency.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunk_size_that_is_not_a_whole_number_of_bytes_uploads_nothing
      [1_048_576.0, 0.5, Rational(1, 2), Float::INFINITY, Float::NAN, "1048576"].each do |chunk_size|
        assert_raises(ArgumentError) { upload("test/sample_files/sample.mp4", chunk_size:) }
        assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", chunk_size:) }
      end
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunked_upload_of_its_own_rejects_a_chunk_size_that_would_need_more_segments
      assert_raises(ArgumentError) { with_large_video { |path| chunked_upload(path, chunk_size: 1_048_576) } }
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_video_of_the_most_the_api_takes_of_an_upload_uploads_in_the_segments_it_numbers
      assert_equal 1_717_987, with_video(16 * 1024**3) { |path| upload(path) }
    end

    def test_a_video_larger_than_the_api_takes_of_an_upload_uploads_nothing
      [:upload, :chunked_upload].each do |method|
        error = assert_raises(InvalidMedia) { with_video((16 * 1024**3) + 1) { |path| __send__(method, path) } }

        assert_match(/is 17179869185 bytes, more than the 17179869184 bytes the API takes of tweet_video media\z/, error.message)
      end
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_chunk_size_larger_than_a_segment_the_api_takes_uploads_nothing
      assert_raises(ArgumentError) { upload("test/sample_files/sample.mp4", chunk_size: 5_242_881) }
      assert_raises(ArgumentError) { chunked_upload("test/sample_files/sample.mp4", chunk_size: 5_242_881) }
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    private

    def chunked_upload(file_path, **)
      Uploader::MediaUpload.chunked_upload(file_path, client: @client, media_category: "tweet_video", **)
    end

    # The size of the chunks the upload of the block would have appended, which it appends none of
    def upload(file_path, **)
      chunk_size = nil
      Uploader.const_get(:Chunks).stub(:append, ->(**options) { chunk_size = options.fetch(:chunk_size) }) do
        Uploader::MediaUpload.upload(file_path, client: @client, media_category: "tweet_video", media_type: "video/mp4", **)
      end
      chunk_size
    end

    def with_large_video(&) = with_video(LARGE_VIDEO_BYTES, &)

    # An empty file read as a size, which costs no disk, as a file of tens of gigabytes would
    def with_video(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.write(path, "")
        File.stub(:size, size) { yield path }
      end
    end
  end
end
