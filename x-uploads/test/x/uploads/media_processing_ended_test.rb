# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # Media that already says its processing has ended, or holds a response that names no processing, is returned as it
  # is, without a request, and the raising form raises for media that says its processing failed, without one too
  class MediaProcessingEndedTest < Minitest::Test
    cover Uploads::MediaUpload

    STATUS_URL = "https://api.x.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze

    def setup
      @client = Client.new
    end

    def test_media_whose_processing_succeeded_is_returned_without_a_request
      media = UploadedMedia.new({"id" => TEST_MEDIA_ID, "size" => 7, "processing_info" => {"state" => "succeeded"}})

      assert_same media, Uploads::MediaUpload.await_processing(media, client: @client)
      assert_same media, Uploads::MediaUpload.await_processing!(media, client: @client)
      assert_not_requested(:get, STATUS_URL)
    end

    def test_media_whose_processing_failed_is_returned_without_a_request
      media = UploadedMedia.new({"id" => TEST_MEDIA_ID, "processing_info" => {"state" => "failed"}})

      assert_same media, Uploads::MediaUpload.await_processing(media, client: @client)
      assert_not_requested(:get, STATUS_URL)
    end

    def test_the_raising_form_raises_for_media_whose_processing_failed_without_a_request
      media = UploadedMedia.new({"id" => TEST_MEDIA_ID, "processing_info" => {"state" => "failed", "error" => {"message" => "bad"}}})
      error = assert_raises(MediaProcessingFailed) { Uploads::MediaUpload.await_processing!(media, client: @client) }

      assert_same media, error.media
      assert_not_requested(:get, STATUS_URL)
    end

    def test_the_hash_of_a_response_that_names_no_processing_is_returned_as_uploaded_media_without_a_request
      response = {"id" => TEST_MEDIA_ID, "media_key" => "3_#{TEST_MEDIA_ID}", "size" => 7}

      assert_equal UploadedMedia.new(response), Uploads::MediaUpload.await_processing(response, client: @client)
      assert_not_requested(:get, STATUS_URL)
    end

    def test_media_known_by_its_identifier_and_media_key_alone_is_checked
      stub_request(:get, STATUS_URL).to_return(headers: {"content-type" => "application/json"},
        body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "succeeded"}}}.to_json)
      status = Uploads::MediaUpload.await_processing({"id" => TEST_MEDIA_ID, "media_key" => "7_#{TEST_MEDIA_ID}"}, client: @client)

      assert_equal "succeeded", status.state
    end
  end
end
