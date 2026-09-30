# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # Media an upload returned still processing is first checked once as long as the upload asked has passed, and media
  # that says nothing of its processing is checked at once
  class MediaFirstCheckTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Utils)

    UPLOAD_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_upload_waits_as_long_as_the_upload_asks_before_the_first_check
      stub_video_upload_that_keeps_processing(check_after_secs: 300, first_check_after_secs: 5)
      waits = []

      on_fake_clock(waits) do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client) }
      end

      assert_equal [5, 300], waits
      assert_requested(:get, status_url, times: 2)
    end

    def test_media_an_upload_asks_to_check_after_the_deadline_is_not_checked
      stub_video_upload_that_keeps_processing(check_after_secs: 1, first_check_after_secs: 60)

      error = on_fake_clock do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, processing_timeout: 30) }
      end

      assert_equal [60, 30, "Media processing did not finish within 30 seconds"], [error.media.check_after_secs, error.timeout, error.message]
      assert_not_requested(:get, status_url)
    end

    def test_media_an_upload_asks_to_check_at_the_deadline_is_checked
      stub_video_upload_that_keeps_processing(check_after_secs: 1, first_check_after_secs: 30)
      waits = []

      on_fake_clock(waits) do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, processing_timeout: 30) }
      end

      assert_equal [30], waits
      assert_requested(:get, status_url, times: 1)
    end

    def test_the_hash_of_an_upload_response_is_first_checked_as_long_as_it_asks
      stub_processing_status_sequence("succeeded")
      response = {"id" => TEST_MEDIA_ID, "processing_info" => {"state" => "pending", "check_after_secs" => 5}}
      waits = []
      status = on_fake_clock(waits) { Uploader::MediaUpload.await_processing(response, client: @client) }

      assert_equal [[5], "succeeded"], [waits, status.state]
      assert_requested(:get, status_url, times: 1)
    end

    def test_the_hash_of_an_upload_response_that_says_nothing_of_processing_is_checked_at_once
      stub_processing_status_sequence("succeeded")
      waits = []
      on_fake_clock(waits) { Uploader::MediaUpload.await_processing({"id" => TEST_MEDIA_ID}, client: @client) }

      assert_empty waits
      assert_requested(:get, status_url, times: 1)
    end

    def test_media_that_is_not_processing_is_checked_at_once
      stub_processing_status_sequence("succeeded")
      waits = []
      on_fake_clock(waits) { Uploader::MediaUpload.await_processing(UploadedMedia.new({"id" => TEST_MEDIA_ID}), client: @client) }

      assert_empty waits
      assert_requested(:get, status_url, times: 1)
    end

    def test_media_an_upload_asks_no_wait_of_is_checked_after_a_second
      stub_video_upload_that_keeps_processing(check_after_secs: 0, first_check_after_secs: nil)
      waits = []

      on_fake_clock(waits) do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, processing_timeout: 2.5) }
      end

      assert_equal [1, 1], waits
    end

    private

    def status_url = "#{UPLOAD_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}"

    def stub_video_upload_that_keeps_processing(check_after_secs:, first_check_after_secs:)
      json = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending", check_after_secs: first_check_after_secs}.compact}}.to_json}
      %W[initialize #{TEST_MEDIA_ID}/append #{TEST_MEDIA_ID}/finalize].each { |path| stub_request(:post, "#{UPLOAD_URL}/#{path}").to_return(json) }
      stub_request(:get, status_url).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending", check_after_secs:}}}.to_json)
    end

    def stub_processing_status_sequence(*states)
      stub = stub_request(:get, status_url)
      states.each { |state| stub = stub.to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state:}}}.to_json) }
    end
  end
end
