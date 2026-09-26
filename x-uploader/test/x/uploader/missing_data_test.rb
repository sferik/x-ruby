# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"
require "x/uploader/metadata"

module X
  # The responses of an upload that describe no media, which every step of one raises MissingData for
  class MissingDataTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Chunks)
    cover Uploader.const_get(:Utils)
    cover UploadedMedia
    cover Uploader::Metadata

    BASE_URL = "https://api.x.com/2/media/upload"
    VIDEO_FILE = "test/sample_files/sample.mp4"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_a_response_of_an_upload_that_holds_no_media_raises
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(MissingData) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client) }

      assert_equal "The response of the upload holds no media", error.message
    end

    def test_data_that_is_not_media_raises_when_the_upload_is_initialized
      stub_init({data: []})

      assert_raises(MissingData) { chunked_upload }
    end

    def test_a_response_that_finalizes_an_upload_without_media_raises
      stub_init({data: {"id" => TEST_MEDIA_ID}})
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(MissingData) { chunked_upload }

      assert_equal "The response that finalizes the upload holds no media", error.message
    end

    def test_alt_text_whose_response_carries_no_body_raises
      stub_request(:post, "https://api.x.com/2/media/metadata").to_return(status: 204)
      error = assert_raises(MissingData) { Uploader::Metadata.add_alt_text(7, "A cat", client: @client) }

      assert_equal "The response that adds the metadata holds none", error.message
    end

    def test_subtitles_whose_response_carries_no_body_raise
      stub_request(:post, "https://api.x.com/2/media/subtitles").to_return(status: 204)

      assert_raises(MissingData) { Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client) }
    end

    def test_metadata_responses_whose_data_is_not_metadata_raise
      stub_request(:post, %r{\Ahttps://api\.x\.com/2/media/(metadata|subtitles)\z}).to_return(headers: JSON_HEADERS, body: {data: []}.to_json)

      assert_raises(MissingData) { Uploader::Metadata.add_alt_text(7, "A cat", client: @client) }
      assert_raises(MissingData) { Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client) }
    end

    def test_media_that_holds_no_identifier_raises
      error = assert_raises(MissingData) { UploadedMedia.new({}).id }

      assert_equal "The media holds no identifier", error.message
    end

    private

    def stub_init(body) = stub_request(:post, "#{BASE_URL}/initialize").to_return(status: 202, headers: JSON_HEADERS, body: body.to_json)

    def chunked_upload = Uploader::MediaUpload.chunked_upload(VIDEO_FILE, client: @client, media_category: Uploader::MediaUpload::TWEET_VIDEO)
  end
end
