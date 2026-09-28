# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaProcessingStatusTest < Minitest::Test
    cover Uploader::MediaUpload

    STATUS_URL = "https://api.x.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze

    def setup
      @client = Client.new
      @sleeps = []
    end

    def test_status_without_processing_info_is_final
      stub_statuses({"id" => TEST_MEDIA_ID})

      assert_equal(UploadedMedia.new({"id" => TEST_MEDIA_ID}), await)
      assert_requested(:get, STATUS_URL, times: 1)
    end

    def test_status_with_null_processing_info_is_final
      stub_statuses({"processing_info" => nil})

      assert_equal(UploadedMedia.new({"processing_info" => nil}), await)
    end

    def test_status_without_state_keeps_polling
      stub_statuses({"processing_info" => {"check_after_secs" => 1}}, {"processing_info" => {"state" => "succeeded"}})

      assert_equal "succeeded", await.dig("processing_info", "state")
      assert_equal [1], @sleeps
    end

    def test_sleeps_for_check_after_secs_between_polls
      stub_statuses({"processing_info" => {"state" => "pending", "check_after_secs" => 2}},
        {"processing_info" => {"state" => "in_progress", "check_after_secs" => 3}},
        {"processing_info" => {"state" => "failed"}})

      assert_equal "failed", await.dig("processing_info", "state")
      assert_equal [2, 3], @sleeps
    end

    def test_sleeps_a_second_without_check_after_secs
      stub_statuses({"processing_info" => {"state" => "pending"}}, {"processing_info" => {"state" => "pending", "check_after_secs" => 0}},
        {"processing_info" => {"state" => "succeeded"}})
      await

      assert_equal [1, 1], @sleeps
    end

    def test_gives_up_once_the_waits_would_pass_the_timeout
      pending = {"processing_info" => {"state" => "in_progress", "check_after_secs" => 5, "progress_percent" => 42}}
      stub_statuses(pending)
      error = assert_raises(MediaProcessingTimeout) { await(processing_timeout: 12) }

      assert_equal [[5, 5], UploadedMedia.new(pending), "Media processing did not finish within 12 seconds"], [@sleeps, error.status, error.message]
      assert_requested(:get, STATUS_URL, times: 3)
    end

    def test_waits_up_to_the_timeout_exactly
      stub_statuses({"processing_info" => {"state" => "pending", "check_after_secs" => 5}}, {"processing_info" => {"state" => "succeeded"}})

      assert_equal "succeeded", await(processing_timeout: 5).dig("processing_info", "state")
    end

    def test_counts_the_time_the_checks_take_toward_the_timeout
      stub_request(:get, STATUS_URL).to_return do
        advance_clock(4)
        {headers: {"content-type" => "application/json"}, body: {data: {processing_info: {state: "pending", check_after_secs: 1}}}.to_json}
      end

      assert_raises(MediaProcessingTimeout) { await(processing_timeout: 10) }
      assert_equal [1, 1], @sleeps
      assert_requested(:get, STATUS_URL, times: 3)
    end

    def test_returns_the_status_of_a_check_that_finishes_after_the_deadline
      responses = [{"state" => "pending", "check_after_secs" => 5}, {"state" => "succeeded"}].map do |processing_info|
        {headers: {"content-type" => "application/json"}, body: {data: {processing_info:}}.to_json}
      end
      stub_request(:get, STATUS_URL).to_return { advance_clock(3) && responses.shift }

      assert_equal "succeeded", await(processing_timeout: 8).dig("processing_info", "state")
      assert_equal [5], @sleeps
    end

    def test_waits_for_as_long_as_processing_takes_without_a_deadline
      stub_statuses(*Array.new(3) { {"processing_info" => {"state" => "pending", "check_after_secs" => 3600}} }, {"processing_info" => {"state" => "succeeded"}})

      assert_equal "succeeded", await(processing_timeout: Float::INFINITY).dig("processing_info", "state")
      assert_equal [3600] * 3, @sleeps
    end

    def test_waits_ten_minutes_by_default
      stub_statuses({"processing_info" => {"state" => "pending", "check_after_secs" => 60}})

      assert_raises(MediaProcessingTimeout) { await }
      assert_equal [60] * 10, @sleeps
    end

    def test_awaits_the_processing_of_a_media_identifier
      stub_request(:get, "https://api.x.com/2/media/upload?command=STATUS&media_id=7")
        .to_return(headers: {"content-type" => "application/json"}, body: {data: {id: "7"}}.to_json)

      [7, "7"].each do |media|
        assert_equal(UploadedMedia.new({"id" => "7"}), Uploader::MediaUpload.await_processing(media, client: @client))
        assert_equal(UploadedMedia.new({"id" => "7"}), Uploader::MediaUpload.await_processing!(media, client: @client))
      end
    end

    def test_media_without_id
      error = assert_raises(MissingMediaData) { Uploader::MediaUpload.await_processing({}, client: @client) }

      assert_equal "The media given holds no identifier", error.message
    end

    def test_a_status_response_that_holds_no_media_raises
      stub_request(:get, STATUS_URL).to_return(headers: {"content-type" => "application/json"}, body: "{}")
      error = assert_raises(MissingMediaData) { await }

      assert_equal "The response of the status check holds no media", error.message
    end

    private

    def await(**)
      on_fake_clock(@sleeps) { Uploader::MediaUpload.await_processing({"id" => TEST_MEDIA_ID}, client: @client, **) }
    end

    def stub_statuses(*statuses)
      responses = statuses.map { |data| {headers: {"content-type" => "application/json"}, body: {data:}.to_json} }
      stub_request(:get, STATUS_URL).to_return(*responses)
    end
  end
end
