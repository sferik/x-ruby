# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaIOTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Source)
    cover Uploader.const_get(:Signature)

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_the_category_of_media_that_names_no_file_is_read_from_its_signature
      {
        "sample.png" => "tweet_image",
        "sample.jpg" => "tweet_image",
        "sample.webp" => "tweet_image",
        "sample.gif" => "tweet_image",
        "sample_animated.gif" => "tweet_gif",
        "sample.mp4" => "tweet_video"
      }.each do |file, category|
        assert_equal category, Uploader::MediaUpload.infer_media_category(StringIO.new(File.binread("test/sample_files/#{file}"))), file
      end
    end

    def test_the_category_of_subtitles_that_name_no_file_is_read_from_their_signature
      assert_equal "subtitles", Uploader::MediaUpload.infer_media_category(StringIO.new("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n"))
    end

    def test_a_heif_image_is_not_taken_for_a_video
      heic = StringIO.new("\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic".b)

      assert_raises(InvalidMediaType) { Uploader::MediaUpload.infer_media_category(heic) }
    end

    def test_the_category_of_media_no_signature_names_must_be_given
      error = assert_raises(InvalidMediaType) { Uploader::MediaUpload.infer_media_category(StringIO.new("not media at all")) }

      assert_equal "unable to determine the media type of the media given: pass media_category", error.message
    end

    def test_the_media_type_of_media_that_names_no_file_is_read_from_its_signature
      png = StringIO.new(File.binread("test/sample_files/sample.png"))

      assert_equal "image/png", Uploader::MediaUpload.infer_media_type(png, "tweet_image")
      assert_equal "video/webm", Uploader::MediaUpload.infer_media_type(StringIO.new("\x1A\x45\xDF\xA3".b), "tweet_video")
    end

    def test_the_media_type_of_a_category_that_takes_no_type_the_signature_names
      mp4 = StringIO.new(File.binread("test/sample_files/sample.mp4"))

      assert_equal "text/srt", Uploader::MediaUpload.infer_media_type(mp4, "subtitles")
    end

    def test_the_media_type_of_media_neither_a_name_nor_a_signature_names
      error = assert_raises(InvalidMediaType) { Uploader::MediaUpload.infer_media_type(StringIO.new("not media at all"), "tweet_image") }

      assert_equal "unable to determine the MIME type of the media given", error.message
    end

    def test_an_image_held_in_memory_uploads_in_a_single_request
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      content = File.binread("test/sample_files/sample.png")
      response = Uploader::MediaUpload.upload(StringIO.new(content), client: @client)

      assert_equal TEST_MEDIA_ID.to_i, response["id"]
      assert_requested(:post, BASE_URL) do |request|
        request.body.include?("name=\"media_category\"\r\n\r\ntweet_image") && request.body.include?(content)
      end
    end

    def test_an_io_open_on_a_file_uploads_as_that_file_does
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      File.open("test/sample_files/sample_animated.gif", "rb") { |file| Uploader::MediaUpload.upload(file, client: @client) }

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_gif") }
    end

    def test_a_video_held_in_memory_uploads_in_chunks
      stub_chunked_workflow
      content = File.binread("test/sample_files/sample.mp4")
      response = Uploader::MediaUpload.upload(StringIO.new(content), client: @client)

      assert_equal TEST_MEDIA_ID.to_i, response["id"]
      assert_requested :post, "#{BASE_URL}/initialize",
        body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: content.bytesize}.to_json
      assert_requested(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append") { |request| request.body.include?(content) }
    end

    def test_an_image_piped_to_stdin_uploads_as_the_image_its_signature_names
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      reader, writer = IO.pipe
      writer.write(File.binread("test/sample_files/sample.png"))
      writer.close
      reader.define_singleton_method(:to_path) { "<STDIN>" }

      assert_equal TEST_MEDIA_ID.to_i, Uploader::MediaUpload.upload(reader, client: @client).id
      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_image") }
    ensure
      reader&.close
    end

    def test_media_that_names_no_file_uploads_under_the_category_it_is_given
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploader::MediaUpload.upload(StringIO.new("not media at all"), client: @client, media_category: "DM_IMAGE")

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ndm_image") }
    end

    def test_media_that_names_no_file_and_holds_nothing_is_refused
      error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload(StringIO.new(""), client: @client, media_category: "tweet_image") }

      assert_equal "the media given is empty: there is nothing to upload", error.message
    end

    def test_a_large_animated_gif_held_in_memory_uploads_in_chunks
      gif = StringIO.new("GIF89a".b + ("\x00".b * (5 * Uploader::MediaUpload::BYTES_PER_MB)))

      assert Uploader::MediaUpload.chunked_upload?(gif, "tweet_gif")
    end

    private

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
