# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaProcessingTest < Minitest::Test
    cover Uploader::Media

    def setup
      @client = Client.new
    end

    def test_await_processing_polls_until_terminal_state
      %w[succeeded failed].each do |terminal_state|
        stub_processing_status_sequence("pending", terminal_state)

        response = await(:await_processing)

        assert_equal terminal_state, response.dig("processing_info", "state")
      end
    end

    def test_await_processing_returns_nil_for_empty_response
      stub_request(:get, status_url).to_return(status: 204)

      response = await(:await_processing)

      assert_nil response
    end

    def test_await_processing_bang_returns_status_on_success
      stub_processing_status_sequence("pending", "succeeded")

      result = await(:await_processing!)

      assert_equal "succeeded", result.dig("processing_info", "state")
    end

    def test_await_processing_bang_raises_on_failure
      stub_processing_status_sequence("pending", "failed")

      error = assert_raises(Uploader::MediaProcessingFailed) do
        await(:await_processing!)
      end

      assert_equal ["Media processing failed", "failed"], [error.message, error.status.dig("processing_info", "state")]
      assert_requested(:get, status_url, times: 2)
    end

    def test_await_processing_bang_returns_nil_for_empty_response
      stub_request(:get, status_url).to_return(status: 204)

      result = await(:await_processing!)

      assert_nil result
    end

    def test_await_processing_bang_gives_up_after_its_timeout
      stub_request(:get, status_url).to_return(headers: json_headers, body: {data: {processing_info: {state: "pending", check_after_secs: 5}}}.to_json)

      assert_raises(Uploader::MediaProcessingTimeout) { await(:await_processing!, processing_timeout: 4) }
      assert_requested(:get, status_url, times: 1)
    end

    def test_upload_gives_up_on_processing_after_the_processing_timeout
      stub_video_upload_that_keeps_processing(check_after_secs: 5)

      assert_raises(Uploader::MediaProcessingTimeout) do
        Uploader::Media.upload("test/sample_files/sample.mp4", client: @client, processing_timeout: 4)
      end
    end

    def test_upload_waits_ten_minutes_for_processing_by_default
      stub_video_upload_that_keeps_processing(check_after_secs: 300)
      waits = []

      Uploader::Media.stub(:sleep, ->(seconds) { waits << seconds }) do
        assert_raises(Uploader::MediaProcessingTimeout) { Uploader::Media.upload("test/sample_files/sample.mp4", client: @client) }
      end

      assert_equal [300, 300], waits
    end

    private

    def stub_video_upload_that_keeps_processing(check_after_secs:)
      json = {headers: json_headers, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending"}}}.to_json}
      %W[initialize #{TEST_MEDIA_ID}/append #{TEST_MEDIA_ID}/finalize].each { |path| stub_request(:post, "https://api.x.com/2/media/upload/#{path}").to_return(json) }
      stub_request(:get, status_url).to_return(headers: json_headers, body: {data: {processing_info: {state: "pending", check_after_secs:}}}.to_json)
    end

    def await(method, **)
      Uploader::Media.stub(:sleep, nil) { Uploader::Media.public_send(method, media_hash, client: @client, **) }
    end

    def media_hash
      {"id" => TEST_MEDIA_ID}
    end

    def status_url
      "https://api.x.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}"
    end

    def json_headers
      {"content-type" => "application/json"}
    end

    def processing_response(state)
      {data: {processing_info: {state: state}}}.to_json
    end

    def stub_processing_status_sequence(*states)
      stub = stub_request(:get, status_url)
      states.each { |state| stub = stub.to_return(headers: json_headers, body: processing_response(state)) }
    end
  end
end
