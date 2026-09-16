require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaRetryTest < Minitest::Test
    cover Uploader::Media
    cover Uploader::Chunks

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    VIDEO_FILE = "test/sample_files/sample.mp4".freeze

    def setup
      @client = Client.new
      @waits = []
    end

    def test_retry_recovers_from_transient_server_error
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500).to_return(status: 204)
      stub_finalize_request

      assert perform_upload
      assert_requested(:post, append_url, times: 2)
      assert_requested(:post, finalize_url, times: 1)
      assert_equal [1], @waits
    end

    def test_retry_recovers_from_a_network_error
      stub_init_request
      stub_request(:post, append_url).to_raise(Errno::ECONNRESET).to_return(status: 204)
      stub_finalize_request

      assert perform_upload
      assert_requested(:post, append_url, times: 2)
    end

    def test_retry_raises_after_exhausting_max_retries
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500)

      with_thread_exceptions_suppressed do
        assert_raises(InternalServerError) { perform_upload }
      end

      assert_requested(:post, append_url, times: Uploader::Chunks::MAX_RETRIES)
      assert_equal [1, 2], @waits
    end

    def test_a_client_error_is_not_retried
      stub_init_request
      stub_request(:post, append_url).to_return(status: 400)

      with_thread_exceptions_suppressed do
        assert_raises(BadRequest) { perform_upload }
      end

      assert_requested(:post, append_url, times: 1)
      assert_empty @waits
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
      Uploader::Media.stub(:sleep, ->(seconds) { @waits << seconds }) do
        Uploader::Media.chunked_upload(VIDEO_FILE, client: @client, media_category: Uploader::Media::TWEET_VIDEO)
      end
    end

    def with_thread_exceptions_suppressed
      original = Thread.report_on_exception
      Thread.report_on_exception = false
      yield
    ensure
      Thread.report_on_exception = original
    end
  end
end
