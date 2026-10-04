# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # Processing ends once it has succeeded or failed alone: a status whose processing names no state, or a state X does
  # not document, as one X adds would be, is still processing, so it is checked again, as often as X asks, or each
  # second when X asks for no wait, until the processing ends or the deadline passes
  class MediaProcessingStateTest < Minitest::Test
    cover Uploads::MediaUpload
    cover Uploads.const_get(:Utils)
    cover UploadedMedia

    UPLOAD_URL = "https://api.x.com/2/media/upload"
    STATUS_URL = "#{UPLOAD_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_a_status_in_no_state_x_documents_is_checked_again_as_often_as_x_asks_until_processing_succeeds
      [{"check_after_secs" => 3}, {"state" => "queued", "check_after_secs" => 3}].each do |processing_info|
        stub_statuses({"processing_info" => processing_info}, {"processing_info" => {"state" => "succeeded"}})
        waits = []
        status = on_fake_clock(waits) { Uploads::MediaUpload.await_processing(TEST_MEDIA_ID, client: @client) }

        assert_equal ["succeeded", true, [3]], [status.state, status.ready?, waits]
      end
    end

    def test_a_status_in_no_state_x_documents_that_asks_for_no_wait_is_checked_again_after_a_second
      stub_statuses({"processing_info" => {"state" => "queued"}}, {"processing_info" => {"state" => "succeeded"}})
      waits = []
      status = on_fake_clock(waits) { Uploads::MediaUpload.await_processing!(TEST_MEDIA_ID, client: @client) }

      assert_equal ["succeeded", [1]], [status.state, waits]
      assert_requested(:get, STATUS_URL, times: 2)
    end

    def test_processing_that_fails_after_a_state_x_does_not_document_raises_from_the_raising_form
      stub_statuses({"processing_info" => {"state" => "queued"}}, {"processing_info" => {"state" => "failed"}})
      error = on_fake_clock { assert_raises(MediaProcessingFailed) { Uploads::MediaUpload.await_processing!(TEST_MEDIA_ID, client: @client) } }

      assert_equal ["Media processing failed", "failed"], [error.message, error.media.state]
    end

    def test_a_state_x_does_not_document_is_waited_for_no_longer_than_the_deadline
      stub_statuses({"processing_info" => {"state" => "queued", "check_after_secs" => 4}})
      waits = []
      error = on_fake_clock(waits) do
        assert_raises(MediaProcessingTimeout) { Uploads::MediaUpload.await_processing!(TEST_MEDIA_ID, client: @client, processing_timeout: 10) }
      end

      assert_equal ["queued", 10, [4, 4]], [error.media.state, error.timeout, waits]
    end

    def test_media_given_in_a_state_x_does_not_document_is_first_checked_as_long_as_it_asks
      stub_statuses({"processing_info" => {"state" => "succeeded"}})
      media = {"id" => TEST_MEDIA_ID, "processing_info" => {"state" => "queued", "check_after_secs" => 7}}
      waits = []
      status = on_fake_clock(waits) { Uploads::MediaUpload.await_processing(media, client: @client) }

      assert_equal ["succeeded", [7]], [status.state, waits]
    end

    def test_an_upload_that_returns_a_state_x_does_not_document_awaits_its_processing
      stub_request(:post, UPLOAD_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "queued"}}}.to_json)
      stub_statuses({"processing_info" => {"state" => "transcoding"}}, {"processing_info" => {"state" => "succeeded"}})
      waits = []
      uploaded = on_fake_clock(waits) { Uploads::MediaUpload.upload("test/sample_files/sample_animated.gif", client: @client) }

      assert_equal ["succeeded", [1, 1]], [uploaded.state, waits]
    end

    private

    def stub_statuses(*statuses)
      responses = statuses.map { |data| {headers: JSON_HEADERS, body: {data: {"id" => TEST_MEDIA_ID, **data}}.to_json} }
      stub_request(:get, STATUS_URL).to_return(*responses)
    end
  end
end
