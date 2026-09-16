require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaChunkedWorkflowTest < Minitest::Test
    cover Uploader::Media
    cover Uploader::Chunks

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    INIT_URL = "#{BASE_URL}/initialize".freeze
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_default_media_category_and_type_are_inferred_from_the_file
      stub_workflow
      Uploader::Media.chunked_upload("test/sample_files/sample.png", client: @client)

      assert_requested(:post, INIT_URL, body: {media_type: "image/png", media_category: "tweet_image", total_bytes: 68}.to_json)
    end

    def test_upload_an_amplify_video_in_chunks_as_mp4
      stub_workflow
      Uploader::Media.upload("test/sample_files/sample.png", client: @client, media_category: "amplify_video")

      assert_requested(:post, INIT_URL, body: {media_type: "video/mp4", media_category: "amplify_video", total_bytes: 68}.to_json)
      assert_not_requested(:post, BASE_URL)
    end

    def test_missing_file_is_rejected_before_requesting
      error = assert_raises(Errno::ENOENT) do
        Uploader::Media.chunked_upload("nope.mp4", client: @client, media_category: "tweet_video")
      end

      assert_equal "No such file or directory - nope.mp4", error.message
    end

    def test_invalid_category_is_rejected_before_requesting
      assert_raises(ArgumentError) do
        Uploader::Media.chunked_upload(VIDEO_FILE, client: @client, media_category: "bogus", media_type: "video/mp4")
      end
      assert_not_requested(:post, INIT_URL)
    end

    def test_media_without_id
      stub_request(:post, INIT_URL).to_return(headers: JSON_HEADERS, body: {data: {}}.to_json)
      error = without_thread_reports do
        assert_raises(KeyError) { Uploader::Media.chunked_upload(VIDEO_FILE, client: @client, media_category: "tweet_video") }
      end

      assert_equal 'key not found: "id"', error.message
    end

    def test_chunks_are_read_from_the_file_without_temporary_files
      stub_workflow
      Dir.stub(:mktmpdir, ->(*) { flunk "wrote a temporary file" }) do
        Uploader::Media.chunked_upload(VIDEO_FILE, client: @client, media_category: "tweet_video", chunk_size_mb: 0.0625)
      end

      assert_requested(:post, APPEND_URL, times: 2)
    end

    def test_an_empty_file_appends_nothing
      stub_workflow
      Dir.mktmpdir do |dir|
        path = File.join(dir, "empty.mp4")
        File.binwrite(path, "")
        Uploader::Media.chunked_upload(path, client: @client, media_category: "tweet_video")
      end

      assert_not_requested(:post, APPEND_URL)
    end

    private

    def stub_workflow
      json = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      stub_request(:post, INIT_URL).to_return(json)
      stub_request(:post, APPEND_URL).to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(json)
    end

    def without_thread_reports
      original = Thread.report_on_exception
      Thread.report_on_exception = false
      yield
    ensure
      Thread.report_on_exception = original
    end
  end
end
