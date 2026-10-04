# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # Stubs the requests of a chunked upload, and records the waits between its retries
  module MediaRetryHelpers
    BASE_URL = "https://api.x.com/2/media/upload"
    VIDEO_FILE = "test/sample_files/sample.mp4"

    def setup
      @client = Client.new
      @waits = []
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

    # Upload with a client whose backoff is cut short by nothing, recording its waits
    def perform_upload
      client = retrying_without_waiting(@client, @waits)
      Uploads::MediaUpload.chunked_upload(VIDEO_FILE, client:, media_category: Uploads::MediaUpload::TWEET_VIDEO)
    end

    def with_thread_exceptions_suppressed
      original = Thread.report_on_exception
      Thread.report_on_exception = false
      yield
    ensure
      Thread.report_on_exception = original
    end
  end

  class MediaRetryTest < Minitest::Test
    include MediaRetryHelpers

    cover Uploads::MediaUpload
    cover Uploads.const_get(:Chunks)
    cover Uploads.const_get(:Utils)

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

    def test_retry_raises_after_exhausting_max_attempts
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500)

      with_thread_exceptions_suppressed do
        assert_instance_of InternalServerError, assert_raises(ChunkedUploadFailed) { perform_upload }.cause
      end

      assert_requested(:post, append_url, times: 3)
      assert_equal [1, 2], @waits
    end

    def test_a_chunk_is_sent_again_as_often_as_the_client_sends_a_request_again
      @client = Client.new(max_retries: 0)
      stub_init_request
      stub_request(:post, append_url).to_return(status: 500)

      with_thread_exceptions_suppressed do
        assert_instance_of InternalServerError, assert_raises(ChunkedUploadFailed) { perform_upload }.cause
      end

      assert_requested(:post, append_url, times: 1)
    end

    def test_a_chunk_waits_as_long_as_a_failed_response_asks
      stub_init_request
      stub_request(:post, append_url).to_return(status: 503, headers: {"Retry-After" => "7"}).to_return(status: 204)
      stub_finalize_request

      assert perform_upload
      assert_equal [7], @waits
    end

    def test_a_chunk_that_is_asked_to_wait_longer_than_a_minute_raises
      stub_init_request
      stub_request(:post, append_url).to_return(status: 503, headers: {"Retry-After" => "120"})

      with_thread_exceptions_suppressed do
        assert_instance_of ServiceUnavailable, assert_raises(ChunkedUploadFailed) { perform_upload }.cause
      end

      assert_requested(:post, append_url, times: 1)
    end

    def test_a_client_error_is_not_retried
      stub_init_request
      stub_request(:post, append_url).to_return(status: 400)

      with_thread_exceptions_suppressed do
        assert_instance_of BadRequest, assert_raises(ChunkedUploadFailed) { perform_upload }.cause
      end

      assert_requested(:post, append_url, times: 1)
      assert_empty @waits
    end
  end

  # The finalize of a chunked upload is sent again as a chunk is
  class MediaFinalizeRetryTest < Minitest::Test
    include MediaRetryHelpers

    cover Uploads.const_get(:Chunks)
    cover Uploads.const_get(:Utils)

    def test_a_finalize_is_sent_again_after_the_api_fails_to_answer_it
      stub_init_request
      stub_request(:post, append_url).to_return(status: 204)
      stub_request(:post, finalize_url).to_return({status: 503}, {status: 201, headers: json_headers, body: {data: media_hash}.to_json})

      assert_equal TEST_MEDIA_ID.to_i, perform_upload.id
      assert_requested(:post, finalize_url, times: 2)
      assert_equal [1], @waits
    end

    def test_a_finalize_is_sent_again_after_a_network_error_as_often_as_the_client_sends_a_request_again
      @client = Client.new(max_retries: 1)
      stub_init_request
      stub_request(:post, append_url).to_return(status: 204)
      stub_request(:post, finalize_url).to_raise(Errno::ECONNRESET)

      assert_instance_of NetworkError, assert_raises(ChunkedUploadFailed) { perform_upload }.cause
      assert_requested(:post, finalize_url, times: 2)
    end
  end
end
