# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # Media uploaded with alt text that cannot be added is kept by the error the upload raises
  class MediaUploadAltTextTest < Minitest::Test
    cover Uploader::MediaUpload
    cover AltTextFailed

    UPLOAD_URL = "https://api.x.com/2/media/upload"
    METADATA_URL = "https://api.x.com/2/media/metadata"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new(max_retries: 0)
      stub_request(:post, UPLOAD_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def test_an_upload_whose_alt_text_is_refused_raises_with_the_media_it_uploaded
      stub_request(:post, METADATA_URL).to_return(status: 400)
      error = assert_raises(AltTextFailed) { upload }

      assert_equal [TEST_MEDIA_ID.to_i, BadRequest], [error.media.id, error.cause.class]
    end

    def test_an_upload_whose_alt_text_never_gets_an_answer_raises_with_the_media_it_uploaded
      stub_request(:post, METADATA_URL).to_raise(Errno::ECONNRESET)

      assert_instance_of NetworkError, assert_raises(AltTextFailed) { upload }.cause
    end

    def test_an_upload_whose_alt_text_the_response_hook_raises_for_raises_with_the_media_it_uploaded
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {}.to_json)
      error = assert_raises(AltTextFailed) { upload(failing_on(METADATA_URL)) }

      assert_equal [TEST_MEDIA_ID.to_i, "#<RuntimeError: Hook failed>"], [error.media.id, error.cause.inspect]
    end

    def test_an_upload_whose_alt_text_does_not_convert_to_utf8_uploads_nothing
      assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, alt_text: "\xFF".b) }
      assert_not_requested :post, UPLOAD_URL
    end

    private

    def upload(client = @client) = Uploader::MediaUpload.upload("test/sample_files/sample.png", client:, alt_text: "A pixel")

    # A client whose on_response hook raises for the response of a request to the URL
    def failing_on(url) = Client.new(on_response: ->(response) { raise "Hook failed" if response.uri.to_s.eql?(url) })
  end
end
