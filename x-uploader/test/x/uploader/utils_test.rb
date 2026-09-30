# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"
require "x/uploader/utils"

module X
  class UtilsTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def test_processed_is_the_status_of_media_that_has_not_failed
      [{"id" => 7}, {"processing_info" => {"state" => "pending"}}, {"processing_info" => {"state" => "succeeded"}}].each do |attrs|
        status = UploadedMedia.new(attrs)

        assert_same status, Uploader.const_get(:Utils).processed!(status)
      end
    end

    def test_processed_raises_for_media_that_failed_to_process
      status = UploadedMedia.new({"processing_info" => {"state" => "failed"}})
      error = assert_raises(MediaProcessingFailed) { Uploader.const_get(:Utils).processed!(status) }

      assert_same status, error.media
      assert_equal "Media processing failed", error.message
    end

    def test_processed_raises_for_media_in_no_state_x_documents
      errors = [{}, {"state" => "queued"}].map do |processing_info|
        status = UploadedMedia.new({"processing_info" => processing_info})
        assert_raises(MediaProcessingFailed) { Uploader.const_get(:Utils).processed!(status) }.then { |error| [error.message, error.media.equal?(status)] }
      end

      assert_equal [["Media processing is in no state X documents: nil", true], ["Media processing is in no state X documents: \"queued\"", true]], errors
    end

    def test_seconds_from_now_on_the_monotonic_clock
      assert_equal [1060, 1000.5], on_fake_clock { [60, 0.5].map { |seconds| Uploader.const_get(:Utils).seconds_from_now(seconds) } }
    end

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
      error = assert_raises(MissingMediaData) { Uploader.const_get(:Utils).media_data(nil, "of the upload") }

      assert_equal "The response of the upload holds no media", error.message
    end

    def test_media_data_of_a_response_whose_data_is_not_media
      assert_raises(MissingMediaData) { Uploader.const_get(:Utils).media_data({"data" => []}, "of the upload") }
    end

    def test_media_data_of_a_response_that_describes_no_media
      error = assert_raises(MissingMediaData) { Uploader.const_get(:Utils).media_data({}, "of the upload") }

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
      assert_raises(ArgumentError) { Uploader.const_get(:Utils).media_id(UploadedMedia.new({"media_key" => "3_7"})) }
    end

    def test_media_id_of_an_identifier
      assert_equal "7", Uploader.const_get(:Utils).media_id(7)
      assert_equal "8", Uploader.const_get(:Utils).media_id("8")
    end

    def test_media_id_of_an_upload_response_without_an_id
      error = assert_raises(ArgumentError) { Uploader.const_get(:Utils).media_id({"media_key" => "3_7"}) }

      assert_equal "The media given holds no identifier", error.message
    end

    def test_media_id_of_what_is_not_media
      [Object.new, 1.5e18, :media].each do |media|
        error = assert_raises(ArgumentError, media.inspect) { Uploader.const_get(:Utils).media_id(media) }

        assert_equal "#{media.inspect} is not media: pass uploaded media, the Hash of an upload response, media that has a " \
          "media key, such as X::Media, a media key, or a media identifier", error.message
      end
    end

    def test_media_id_of_media_that_has_a_media_key
      assert_equal "1880028106020515840", Uploader.const_get(:Utils).media_id(Struct.new(:media_key).new("3_1880028106020515840"))
    end

    def test_media_id_of_media_whose_media_key_names_no_identifier
      ["3_", "_7", "3_7x", "x3_7", "3-7", "3_7\n", 37].each do |key|
        error = assert_raises(ArgumentError, key.inspect) { Uploader.const_get(:Utils).media_id(Struct.new(:media_key).new(key)) }

        assert_equal "The media key #{key.inspect} names no media identifier", error.message
      end
    end

    def test_media_id_of_media_that_has_no_media_key
      error = assert_raises(ArgumentError) { Uploader.const_get(:Utils).media_id(Struct.new(:media_key).new(nil)) }

      assert_equal "The media given holds no identifier", error.message
    end

    def test_media_id_of_nothing
      [nil, "", {"id" => nil}, {"id" => ""}].each do |media|
        error = assert_raises(ArgumentError, media.inspect) { Uploader.const_get(:Utils).media_id(media) }

        assert_equal "The media given holds no identifier", error.message
      end
    end

    def test_awaiting_the_processing_of_nothing_sends_no_request
      assert_raises(ArgumentError) { Uploader::MediaUpload.await_processing(nil, client: Client.new) }
      assert_not_requested :any, /api\.x\.com/
    end
  end

  class UploaderMediaIdentifierTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def test_media_data_of_a_response_whose_media_holds_no_identifier
      error = assert_raises(MissingMediaData) { Uploader.const_get(:Utils).media_data({"data" => {"size" => 3}}, "of the upload") }

      assert_equal "The response of the upload holds no media", error.message
    end

    def test_media_id_refuses_an_identifier_the_api_does_not_take
      [" 7", "-7", "7 ", "abc", "1" * 20, -7, {"id" => "abc"}, UploadedMedia.new({"id" => "7x"})].each do |media|
        error = assert_raises(ArgumentError, media.inspect) { Uploader.const_get(:Utils).media_id(media) }

        assert_match(/\AThe media identifier ".*" is none the API takes, which is 1 to 19 digits\z/, error.message)
      end
    end

    def test_media_id_takes_the_longest_identifier_the_api_takes
      assert_equal "9" * 19, Uploader.const_get(:Utils).media_id("9" * 19)
    end
  end
end
