require_relative "../test_helper"
require_relative "../../lib/x/media_uploader"

module X
  class MediaUploaderProcessingTest < Minitest::Test
    cover MediaUploader

    def setup
      @client = Client.new
    end

    def test_await_processing_polls_until_terminal_state
      %w[succeeded failed].each do |terminal_state|
        stub_processing_status_sequence("pending", terminal_state)

        response = MediaUploader.await_processing(client: @client, media: media_hash)

        assert_equal terminal_state, response.dig("processing_info", "state")
      end
    end

    def test_await_processing_returns_nil_for_empty_response
      stub_request(:get, status_url).to_return(status: 204)

      response = MediaUploader.await_processing(client: @client, media: media_hash)

      assert_nil response
    end

    def test_await_processing_bang_returns_status_on_success
      stub_processing_status_sequence("pending", "succeeded")

      result = MediaUploader.await_processing!(client: @client, media: media_hash)

      assert_equal "succeeded", result.dig("processing_info", "state")
    end

    def test_await_processing_bang_raises_on_failure
      stub_processing_status_sequence("pending", "failed")

      error = assert_raises(RuntimeError) do
        MediaUploader.await_processing!(client: @client, media: media_hash)
      end

      assert_equal "Media processing failed", error.message
      assert_requested(:get, status_url, times: 2)
    end

    def test_await_processing_bang_returns_nil_for_empty_response
      stub_request(:get, status_url).to_return(status: 204)

      result = MediaUploader.await_processing!(client: @client, media: media_hash)

      assert_nil result
    end

    private

    def media_hash
      {"id" => TEST_MEDIA_ID}
    end

    def status_url
      "https://api.twitter.com/2/media/upload?command=STATUS&media_id=#{TEST_MEDIA_ID}"
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
