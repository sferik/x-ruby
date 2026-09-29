# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # A status whose processing names no state, or a state X does not document, is neither processing nor ready: it
  # is returned without another check, since X gives no time to check it again at, and raises from the raising form
  class MediaProcessingStateTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Utils)

    STATUS_URL = "https://api.x.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze

    def setup
      @client = Client.new
    end

    def test_a_status_in_no_state_x_documents_is_returned_as_neither_processing_nor_ready
      [{"check_after_secs" => 1}, {"state" => "queued", "check_after_secs" => 1}].each do |processing_info|
        stub_statuses({"processing_info" => processing_info}, {"processing_info" => {"state" => "succeeded"}})
        waits = []
        status = on_fake_clock(waits) { Uploader::MediaUpload.await_processing(TEST_MEDIA_ID, client: @client) }

        assert_equal [processing_info, false, false, []], [status.processing_info, status.processing?, status.ready?, waits]
      end
    end

    def test_the_raising_form_raises_for_a_status_in_no_state_x_documents
      stub_statuses({"processing_info" => {"state" => "queued"}})
      error = assert_raises(MediaProcessingFailed) { Uploader::MediaUpload.await_processing!(TEST_MEDIA_ID, client: @client) }

      assert_equal ["Media processing is in no state X documents: \"queued\"", "queued"], [error.message, error.status.state]
    end

    private

    def stub_statuses(*statuses)
      responses = statuses.map { |data| {headers: {"content-type" => "application/json"}, body: {data:}.to_json} }
      stub_request(:get, STATUS_URL).to_return(*responses)
    end
  end
end
