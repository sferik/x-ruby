require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderRetryTest < Minitest::Test
    cover MediaUploader

    BASE_URL = "https://api.twitter.com/2/media/upload".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze

    def setup
      @client = Client.new
    end

    def test_retry_recovers_from_transient_server_error
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500).to_return(status: 204)
      stub_finalize_request

      assert perform_upload
      assert_requested(:post, append_url, times: 2)
      assert_requested(:post, finalize_url, times: 1)
    end

    def test_retry_raises_after_exhausting_max_retries
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500)

      with_thread_exceptions_suppressed do
        assert_raises(InternalServerError) { perform_upload }
      end

      assert_requested(:post, append_url, times: MediaUploader::MAX_RETRIES)
    end

    def test_cleanup_preserves_nonempty_directory
      Dir.mktmpdir do |dir|
        file_to_delete, file_to_keep = create_temp_files(dir, 2)

        MediaUploader.send(:cleanup_file, file_to_delete)

        refute_path_exists file_to_delete
        assert_path_exists file_to_keep
        assert Dir.exist?(dir)
      end
    end

    private

    def media_hash = {"id" => TEST_MEDIA_ID}
    def json_headers = {"content-type" => "application/json"}
    def init_url = "#{BASE_URL}/initialize"
    def append_url = "#{BASE_URL}/#{TEST_MEDIA_ID}/append"
    def finalize_url = "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize"

    def stub_init_request
      stub_request(:post, init_url).to_return(status: 202, headers: json_headers, body: {data: media_hash}.to_json)
    end

    def stub_finalize_request
      stub_request(:post, finalize_url).to_return(status: 201, headers: json_headers, body: {data: media_hash}.to_json)
    end

    def perform_upload
      MediaUploader.chunked_upload(client: @client, file_path: VIDEO_FILE, media_category: MediaUploader::TWEET_VIDEO)
    end

    def with_thread_exceptions_suppressed
      original = Thread.report_on_exception
      Thread.report_on_exception = false
      yield
    ensure
      Thread.report_on_exception = original
    end

    def create_temp_files(dir, count)
      Array.new(count) do |i|
        path = File.join(dir, "file#{i}.tmp")
        File.write(path, "content#{i}")
        path
      end
    end
  end
end
