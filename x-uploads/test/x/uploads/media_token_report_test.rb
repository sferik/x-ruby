# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # A request of an upload that refreshes the tokens, and whose save_tokens raises for them, raises TokenReportFailed
  # as any other request does, whatever the upload has done by then, so that a rescue of it stores the tokens it holds
  class MediaTokenReportTest < Minitest::Test
    cover Uploads::MediaUpload
    cover Uploads.const_get(:Chunks)
    cover ChunkedUploadFailed
    cover MediaProcessingCheckFailed
    cover AltTextFailed

    BASE_URL = "https://api.x.com/2/media/upload"
    STATUS_URL = "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze
    METADATA_URL = "https://api.x.com/2/media/metadata"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    MEDIA = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze
    PENDING = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending"}}}.to_json}.freeze
    EXPIRED = {status: 401}.freeze

    def setup
      @client = Client.new(client_id: "CLIENT_ID", access_token: "ACCESS_TOKEN", refresh_token: "REFRESH_TOKEN",
        save_tokens: ->(_tokens) { raise "Store is down" })
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
      stub_request(:post, "#{BASE_URL}/initialize").to_return(MEDIA)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
    end

    def test_a_finalize_whose_save_tokens_raises_raises_with_the_tokens
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(EXPIRED, MEDIA)

      assert_holds_the_tokens(assert_raises(TokenReportFailed) { upload("test/sample_files/sample.mp4") })
    end

    def test_a_check_of_processing_whose_save_tokens_raises_raises_with_the_tokens
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(PENDING)
      stub_request(:get, STATUS_URL).to_return(EXPIRED, MEDIA)

      assert_holds_the_tokens(assert_raises(TokenReportFailed) { on_fake_clock { upload("test/sample_files/sample.mp4") } })
    end

    def test_alt_text_whose_save_tokens_raises_raises_with_the_tokens
      stub_request(:post, BASE_URL).to_return(MEDIA)
      stub_request(:post, METADATA_URL).to_return(EXPIRED, MEDIA)

      assert_holds_the_tokens(assert_raises(TokenReportFailed) { upload("test/sample_files/sample.png", alt_text: "A pixel") })
    end

    private

    def upload(media, **) = Uploads::MediaUpload.upload(media, client: @client, **)

    def assert_holds_the_tokens(error)
      assert_equal ["NEW_REFRESH_TOKEN", "#<RuntimeError: Store is down>"], [error.tokens.refresh_token, error.cause.inspect]
    end
  end
end
