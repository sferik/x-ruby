# frozen_string_literal: true

require "tempfile"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaTempfileTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Signature)

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_the_category_of_a_file_whose_extension_names_no_type_is_read_from_its_signature
      {"sample.png" => "tweet_image", "sample_animated.gif" => "tweet_gif", "sample.mp4" => "tweet_video"}.each do |file, category|
        in_tempfile(file) { |tempfile| assert_equal category, Uploader::MediaUpload.infer_media_category(tempfile), file }
      end
    end

    def test_a_file_whose_extension_and_signature_name_no_type_is_an_image
      Tempfile.create("unknown") do |tempfile|
        tempfile.write("not media at all")

        assert_equal "tweet_image", Uploader::MediaUpload.infer_media_category(tempfile)
      end
    end

    def test_a_file_whose_extension_names_an_image_is_one_whatever_it_begins_with
      Tempfile.create(%w[media .png]) do |tempfile|
        tempfile.binmode
        tempfile.write(File.binread("test/sample_files/sample.mp4"))

        assert_equal "tweet_image", Uploader::MediaUpload.infer_media_category(tempfile)
      end
    end

    def test_a_missing_file_whose_extension_names_no_type_is_an_image
      assert_equal "tweet_image", Uploader::MediaUpload.infer_media_category("missing")
    end

    def test_the_media_type_of_a_file_whose_extension_names_no_type_is_read_from_its_signature
      in_tempfile("sample.mp4") { |tempfile| assert_equal "video/mp4", Uploader::MediaUpload.infer_media_type(tempfile, "tweet_video") }
      in_tempfile("sample.png") { |tempfile| assert_equal "image/png", Uploader::MediaUpload.infer_media_type(tempfile, "tweet_image") }
    end

    def test_the_media_type_of_a_missing_file_whose_extension_names_no_type_cannot_be_read
      error = assert_raises(InvalidMediaType) { Uploader::MediaUpload.infer_media_type("missing", "tweet_image") }

      assert_equal "unable to determine the MIME type of missing", error.message
    end

    def test_a_video_in_a_tempfile_uploads_in_chunks
      stub_chunked_workflow
      in_tempfile("sample.mp4") { |tempfile| Uploader::MediaUpload.upload(tempfile, client: @client) }

      assert_requested :post, "#{BASE_URL}/initialize", body: hash_including("media_category" => "tweet_video", "media_type" => "video/mp4")
    end

    private

    # Copy a sample file into a Tempfile, whose name has no extension, and yield it
    def in_tempfile(file)
      Tempfile.create("media") do |tempfile|
        tempfile.binmode
        tempfile.write(File.binread("test/sample_files/#{file}"))
        yield tempfile
      end
    end

    def stub_chunked_workflow
      stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize")
        .to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "succeeded"}}}.to_json)
      stub_request(:get, "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "succeeded"}}}.to_json)
    end
  end
end
