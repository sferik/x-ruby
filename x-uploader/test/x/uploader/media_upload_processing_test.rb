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
      response = on_fake_clock { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) }

      assert_equal "succeeded", response.dig("processing_info", "state")
      assert_requested :get, STATUS_URL
    end

    def test_upload_raises_when_an_animated_gif_fails_to_process
      stub_pending_upload
      stub_status(state: "failed")

      assert_raises(MediaProcessingFailed) { on_fake_clock { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) } }
    end

    def test_upload_waits_the_processing_timeout_for_an_animated_gif
      stub_pending_upload
      stub_status(state: "in_progress", check_after_secs: 5)
      error = Uploader.const_get(:Utils).stub(:sleep, nil) do
        assert_raises(MediaProcessingTimeout) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client, processing_timeout: 4) }
      end

      assert_equal "Media processing did not finish within the 4 seconds allowed: its next check would come after them", error.message
    end

    def test_upload_keeps_the_media_when_a_check_of_its_processing_fails
      stub_pending_upload
      stub_request(:get, STATUS_URL).to_return(status: 400, headers: JSON_HEADERS, body: {title: "Invalid Request"}.to_json)
      error = Uploader.const_get(:Utils).stub(:sleep, nil) do
        assert_raises(MediaProcessingCheckFailed) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) }
      end

      assert_equal [TEST_MEDIA_ID, "pending", BadRequest], [error.media["id"], error.media.state, error.cause.class]
    end

    def test_upload_names_the_media_it_kept_when_a_check_of_its_processing_fails
      stub_pending_upload
      stub_request(:get, STATUS_URL).to_return(status: 400, headers: JSON_HEADERS, body: {title: "Invalid Request"}.to_json)
      error = Uploader.const_get(:Utils).stub(:sleep, nil) do
        assert_raises(MediaProcessingCheckFailed) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) }
      end

      assert error.message.start_with?("Media #{TEST_MEDIA_ID} was uploaded, but its processing could not be checked: ")
    end

    def test_upload_checks_no_status_of_media_that_has_already_been_processed
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "succeeded"}}}.to_json)
      response = Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client)

      assert_equal "succeeded", response.state
      assert_not_requested :get, STATUS_URL
    end

    def test_upload_raises_for_media_that_has_already_failed_to_process_without_checking_its_status
      failed = {"id" => TEST_MEDIA_ID, "processing_info" => {"state" => "failed", "error" => {"message" => "Unsupported"}}}
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: failed}.to_json)
      error = assert_raises(MediaProcessingFailed) { Uploader::MediaUpload.upload(ANIMATED_GIF, client: @client) }

      assert_equal UploadedMedia.new(failed), error.media
      assert_not_requested :get, STATUS_URL
    end

    def test_upload_an_image_that_needs_no_processing
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)

      assert_equal(UploadedMedia.new({"id" => TEST_MEDIA_ID}), Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client))
      assert_not_requested :get, STATUS_URL
    end

    def test_upload_an_image_whose_response_holds_media_without_an_identifier_raises
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {size: 3}}.to_json)

      assert_raises(MissingMediaData) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client) }
    end

    def test_upload_an_image_without_a_response_body_raises
      stub_request(:post, BASE_URL).to_return(status: 204)
      error = assert_raises(MissingMediaData) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client) }

      assert_equal "The response of the upload holds no media", error.message
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
