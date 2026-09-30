# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../test_helper"

module X
  # Media that changes, or can no longer be read, once a chunked upload is initialized fails the upload with the media
  # it initialized, and a file that grows appends only the bytes the upload declared
  class ChunkedUploadChangedMediaTest < Minitest::Test
    cover ChunkedUploadFailed
    cover Uploader.const_get(:Chunks)
    cover Uploader.const_get(:Source)

    BASE_URL = "https://api.x.com/2/media/upload"
    INIT_URL = "#{BASE_URL}/initialize".freeze
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    JSON = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze
    SIZE = File.size("test/sample_files/sample.mp4")
    DECLARED = /"total_bytes":#{SIZE}\b/

    def setup
      @dir = Dir.mktmpdir
      @path = File.join(@dir, "video.mp4")
      FileUtils.cp("test/sample_files/sample.mp4", @path)
      @appended = []
      stub_request(:post, APPEND_URL).to_return { |request| (@appended << request.body) and {status: 204} }
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(JSON)
    end

    def teardown
      super
      FileUtils.rm_rf(@dir)
    end

    # Initialize the upload, then change the media as the block says
    def once_initialized(&change) = stub_request(:post, INIT_URL).to_return { (change.call and JSON) || JSON }

    def upload(media = @path, **) = Uploader::MediaUpload.chunked_upload(media, client: Client.new, media_category: "tweet_video", **)

    def failure(media = @path, **)
      without_thread_reports { assert_raises(ChunkedUploadFailed) { upload(media, **) } }
    end

    def without_thread_reports
      original = Thread.report_on_exception
      Thread.report_on_exception = false
      yield
    ensure
      Thread.report_on_exception = original
    end

    def test_a_file_deleted_once_the_upload_is_initialized_fails_it_with_the_media
      once_initialized { File.delete(@path) }
      error = failure

      assert_equal [TEST_MEDIA_ID.to_i, Errno::ENOENT], [error.media.id, error.cause.class]
    end

    def test_a_file_closed_once_the_upload_is_initialized_fails_it_with_the_media
      file = File.open(@path, "rb")
      once_initialized { file.close }
      error = failure(file)

      assert_equal [TEST_MEDIA_ID.to_i, IOError], [error.media.id, error.cause.class]
    end

    def test_a_file_that_shrinks_once_the_upload_is_initialized_fails_it_with_the_media
      once_initialized { File.truncate(@path, 100) }
      error = failure(chunk_size_mb: 0.1, concurrency: 1)

      assert_equal [TEST_MEDIA_ID.to_i, EOFError], [error.media.id, error.cause.class]
      assert_equal "#{@path} held #{SIZE} bytes when the upload was initialized, but chunk 0 read 100 of the 104858 it " \
        "began with at byte 0: the media changed while it was uploaded", error.cause.message
    end

    def test_a_chunk_that_reads_nothing_fails_the_upload
      once_initialized { File.truncate(@path, 0) }

      assert_equal "#{@path} held #{SIZE} bytes when the upload was initialized, but chunk 0 read 0 of the #{SIZE} it " \
        "began with at byte 0: the media changed while it was uploaded", failure.cause.message
    end

    def test_a_file_that_grows_once_the_upload_is_initialized_appends_the_bytes_it_declared
      once_initialized { File.write(@path, "GROWN", mode: "ab") }
      upload(chunk_size_mb: 0.1)

      assert_requested(:post, INIT_URL, body: DECLARED)
      assert_equal 2, @appended.size
      assert @appended.none? { |body| body.include?("GROWN") }
    end

    def test_a_file_open_that_grows_once_the_upload_is_initialized_appends_the_bytes_it_declared
      File.open(@path, "rb") do |file|
        once_initialized { File.write(@path, "GROWN", mode: "ab") }
        upload(file)
      end

      assert_requested(:post, INIT_URL, body: DECLARED)
      assert @appended.none? { |body| body.include?("GROWN") }
    end

    def test_an_error_that_is_not_one_of_the_media_or_the_api_is_raised_as_it_is
      assert_raises(ArgumentError) { ChunkedUploadFailed.__send__(:keeping, {}) { raise ArgumentError } }
      assert_raises(ChunkedUploadFailed) { ChunkedUploadFailed.__send__(:keeping, {}) { raise Errno::EACCES } }
      assert_raises(ChunkedUploadFailed) { ChunkedUploadFailed.__send__(:keeping, {}) { raise IOError } }
    end
  end
end
