# frozen_string_literal: true

require "tempfile"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaUploadValidationTest < Minitest::Test
    cover Uploader::MediaUpload

    BASE_URL = "https://api.x.com/2/media/upload"
    METADATA_URL = "https://api.x.com/2/media/metadata"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_upload_rejects_a_missing_image_before_reading_it
      error = assert_raises(Errno::ENOENT) { Uploader::MediaUpload.upload("nope.png", client: @client) }

      assert_equal "No such file or directory - nope.png", error.message
      assert_not_requested :post, BASE_URL
    end

    def test_upload_rejects_an_empty_file_before_any_request
      %w[.mp4 .png].each do |extension|
        Tempfile.create(["empty", extension]) do |file|
          assert_raises(ArgumentError) { Uploader::MediaUpload.upload(file.path, client: @client) }
          assert_raises(ArgumentError) { Uploader::MediaUpload.chunked_upload(file.path, client: @client, media_category: :tweet_video) }
        end
      end

      assert_not_requested :post, "#{BASE_URL}/initialize"
      assert_not_requested :post, BASE_URL
    end

    def test_upload_rejects_a_chunk_size_that_is_not_positive_whatever_the_upload
      assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, chunk_size_mb: 0) }
      assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, concurrency: 0) }
      assert_not_requested :post, BASE_URL
    end

    def test_upload_rejects_alt_text_the_api_would_refuse_before_uploading_anything
      error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, alt_text: "A" * 1001) }

      assert_equal "alt_text must be 1 to 1000 characters, not 1001", error.message
      assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, alt_text: "") }
      assert_not_requested :post, "#{BASE_URL}/initialize"
      assert_not_requested :post, BASE_URL
    end

    def test_upload_describes_media_with_the_longest_alt_text_the_api_takes
      stub_upload_request
      stub_request(:post, METADATA_URL).to_return(status: 204)
      Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, alt_text: "A" * 1000)

      assert_requested :post, METADATA_URL, body: {id: TEST_MEDIA_ID, metadata: {alt_text: {text: "A" * 1000}}}.to_json
    end

    def test_upload_takes_the_media_category_of_an_upload_in_chunks_as_a_symbol
      stub_chunked_workflow
      Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, media_category: :DM_VIDEO, media_type: "video/mp4")

      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "video/mp4", media_category: "dm_video", total_bytes: 68}.to_json
    end

    def test_upload_takes_the_media_category_of_an_upload_in_a_single_request_as_a_symbol
      stub_upload_request
      Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, media_category: :TWEET_IMAGE)

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_image") }
    end

    def test_upload_binary_takes_the_media_category_as_a_symbol
      stub_upload_request
      Uploader::MediaUpload.upload_binary("GIF89a", client: @client, media_category: :TWEET_GIF)

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_gif") }
    end

    def test_chunked_upload_takes_the_media_category_as_a_symbol
      stub_chunked_workflow
      Uploader::MediaUpload.chunked_upload("test/sample_files/sample.srt", client: @client, media_category: :SUBTITLES)

      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "text/srt", media_category: "subtitles", total_bytes: File.size("test/sample_files/sample.srt")}.to_json
    end

    def test_upload_raises_for_a_media_category_that_names_none
      error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload("test/sample_files/sample.png", client: @client, media_category: :bogus) }

      assert_includes error.message, "Invalid media_category: bogus"
      assert_not_requested :post, BASE_URL
    end

    private

    def stub_upload_request
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def stub_chunked_workflow
      json = {headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      stub_request(:post, "#{BASE_URL}/initialize").to_return(json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(json)
    end
  end
end
