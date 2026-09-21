# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media"

module X
  # The responses of an upload that describe no media, which every step of one raises MissingData for
  class MissingDataTest < Minitest::Test
    cover Uploader::Media
    cover Uploader.const_get(:Chunks)
    cover Uploader.const_get(:Utils)
    cover Uploader::UploadedMedia

    BASE_URL = "https://api.x.com/2/media/upload"
    VIDEO_FILE = "test/sample_files/sample.mp4"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_a_response_of_an_upload_that_holds_no_media_raises
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(Uploader::MissingData) { Uploader::Media.upload("test/sample_files/sample.png", client: @client) }

      assert_equal "The response of the upload holds no media", error.message
    end

    def test_data_that_is_not_media_raises_when_the_upload_is_initialized
      stub_init({data: []})

      assert_raises(Uploader::MissingData) { chunked_upload }
    end

    def test_a_response_that_finalizes_an_upload_without_media_raises
      stub_init({data: {"id" => TEST_MEDIA_ID}})
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(Uploader::MissingData) { chunked_upload }

      assert_equal "The response that finalizes the upload holds no media", error.message
    end

    def test_media_that_holds_no_identifier_raises
      error = assert_raises(Uploader::MissingData) { Uploader::UploadedMedia.new({}).id }

      assert_equal "The media holds no identifier", error.message
    end

    private

    def stub_init(body) = stub_request(:post, "#{BASE_URL}/initialize").to_return(status: 202, headers: JSON_HEADERS, body: body.to_json)

    def chunked_upload = Uploader::Media.chunked_upload(VIDEO_FILE, client: @client, media_category: Uploader::Media::TWEET_VIDEO)
  end
end
