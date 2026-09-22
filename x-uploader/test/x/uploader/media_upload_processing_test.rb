# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaUploadProcessingTest < Minitest::Test
    cover Uploader::MediaUpload

    BASE_URL = "https://api.x.com/2/media/upload"
    STATUS_URL = "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    ANIMATED_GIF = "test/sample_files/sample_animated.gif"

    def setup
      @client = Client.new
    end

    def test_upload_awaits_the_processing_of_an_animated_gif
      stub_pending_upload
      stub_status(state: "succeeded")
      response = Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client)

      assert_equal "succeeded", response.dig("processing_info", "state")
      assert_requested :get, STATUS_URL
    end

    def test_upload_raises_when_an_animated_gif_fails_to_process
      stub_pending_upload
      stub_status(state: "failed")

      assert_raises(MediaProcessingFailed) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) }
    end

    def test_upload_waits_the_processing_timeout_for_an_animated_gif
      stub_pending_upload
      stub_status(state: "in_progress", check_after_secs: 5)
      error = Uploader::MediaUpload.stub(:sleep, nil) do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client, processing_timeout: 4) }
      end

      assert_equal "Media processing did not finish within 4 seconds", error.message
    end

    def test_upload_an_image_that_needs_no_processing
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)

      assert_equal(UploadedMedia.new({"id" => TEST_MEDIA_ID}), Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client))
      assert_not_requested :get, STATUS_URL
    end

    def test_upload_an_image_without_a_response_body
      stub_request(:post, BASE_URL).to_return(status: 204)

      assert_nil Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client)
      assert_not_requested :get, STATUS_URL
    end

    private

    def stub_pending_upload
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending"}}}.to_json)
    end

    def stub_status(**processing_info)
      stub_request(:get, STATUS_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info:}}.to_json)
    end
  end
end
