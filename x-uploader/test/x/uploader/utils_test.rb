# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"
require "x/uploader/utils"

module X
  class UtilsTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def test_extension_is_lowercase_and_has_no_dot
      assert_equal "jpg", Uploader.const_get(:Utils).extension("photos/cat.JPG")
    end

    def test_extension_of_a_pathname
      assert_equal "png", Uploader.const_get(:Utils).extension(Pathname("avatar.png"))
    end

    def test_extension_of_a_file_without_one
      assert_equal "", Uploader.const_get(:Utils).extension("README")
    end

    def test_media_data_of_a_response_that_describes_media
      assert_equal({"id" => 7}, Uploader.const_get(:Utils).media_data({"data" => {"id" => 7}}, "of the upload"))
    end

    def test_media_data_of_a_response_that_carries_no_body
      assert_nil Uploader.const_get(:Utils).media_data(nil, "of the upload")
    end

    def test_media_data_of_a_response_that_describes_no_media
      error = assert_raises(MissingData) { Uploader.const_get(:Utils).media_data({}, "of the upload") }

      assert_equal "The response of the upload holds no media", error.message
    end

    def test_media_id_of_an_upload_response
      assert_equal "7", Uploader.const_get(:Utils).media_id({"id" => 7, "media_key" => "3_7"})
    end

    def test_media_id_of_a_response_parsed_into_a_hash_subclass
      response = Class.new(Hash).new
      response["id"] = "7"

      assert_equal "7", Uploader.const_get(:Utils).media_id(response)
    end

    def test_media_id_of_uploaded_media
      assert_equal "7", Uploader.const_get(:Utils).media_id(UploadedMedia.new({"id" => "7"}))
      assert_equal "7", Uploader.const_get(:Utils).media_id(Class.new(UploadedMedia).new({"id" => "7"}))
    end

    def test_media_id_of_uploaded_media_without_an_id
      assert_raises(MissingData) { Uploader.const_get(:Utils).media_id(UploadedMedia.new({"media_key" => "3_7"})) }
    end

    def test_media_id_of_an_identifier
      assert_equal "7", Uploader.const_get(:Utils).media_id(7)
      assert_equal "8", Uploader.const_get(:Utils).media_id("8")
    end

    def test_media_id_of_an_upload_response_without_an_id
      error = assert_raises(MissingData) { Uploader.const_get(:Utils).media_id({"media_key" => "3_7"}) }

      assert_equal "The media given holds no identifier", error.message
    end

    def test_media_id_of_nothing
      [nil, "", {"id" => nil}, {"id" => ""}].each do |media|
        error = assert_raises(MissingData, media.inspect) { Uploader.const_get(:Utils).media_id(media) }

        assert_equal "The media given holds no identifier", error.message
      end
    end

    def test_awaiting_the_processing_of_nothing_sends_no_request
      assert_raises(MissingData) { Uploader::MediaUpload.await_processing(nil, client: Client.new) }
      assert_not_requested :any, /api\.x\.com/
    end
  end
end
