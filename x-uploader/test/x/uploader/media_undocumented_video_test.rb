# frozen_string_literal: true

require_relative "../../test_helper"
require "tempfile"
require "x/uploader/media_upload"

module X
  # A video of a container the API documents no media type for, AVI or Matroska, is refused before a request, rather
  # than sent as a type it is not, unless it begins with the signature of a type the API documents, as WebM does
  class MediaUndocumentedVideoTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Signature)

    EBML_HEADER = "\x1A\x45\xDF\xA3\x9F\x42\x86\x81\x01\x42\xF7\x81\x01\x42\xF2\x81\x04\x42\xF3\x81\x08"
    MATROSKA = "#{EBML_HEADER}\x42\x82\x88matroska\x42\x87\x81\x04\x42\x85\x81\x02".b.freeze
    WEBM = "#{EBML_HEADER}\x42\x82\x84webm\x42\x87\x81\x04\x42\x85\x81\x02".b.freeze
    AVI = "RIFF\x00\x00\x00\x00AVI LIST".b.freeze

    def setup
      @client = Client.new
    end

    def test_a_matroska_video_is_refused
      in_file(".mkv", MATROSKA) do |path|
        message = "the API documents no media type for Matroska video, such as #{path}: convert it to MP4, QuickTime, WebM, or MPEG-TS"

        assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_category(path) }.message
        assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_type(path, "tweet_video") }.message
      end
    end

    def test_an_avi_video_is_refused_whatever_case_its_extension_is_in
      in_file(".AVI", AVI) do |path|
        error = assert_raises(InvalidMediaType) { inference.infer_media_category(path) }

        assert_match(/documents no media type for AVI video/, error.message)
      end
    end

    def test_such_a_file_that_cannot_be_read_is_refused
      assert_raises(InvalidMediaType) { inference.infer_media_category("missing.mkv") }
      assert_raises(InvalidMediaType) { inference.infer_media_type("missing.avi", "tweet_video") }
    end

    def test_a_webm_video_named_as_matroska_uploads_as_webm
      in_file(".mkv", WEBM) do |path|
        assert_equal "tweet_video", inference.infer_media_category(path)
        assert_equal "video/webm", inference.infer_media_type(path, "tweet_video")
      end
    end

    def test_an_upload_of_a_matroska_video_sends_no_request
      in_file(".mkv", MATROSKA) do |path|
        assert_raises(InvalidMediaType) { Uploader::MediaUpload.upload(path, client: @client) }
        assert_raises(InvalidMediaType) { Uploader::MediaUpload.upload(path, client: @client, media_category: "tweet_video") }
      end

      assert_not_requested :any, /x\.com/
    end

    def test_a_nameless_matroska_video_is_refused_whatever_category_it_is_given
      message = "the API documents no media type for Matroska video, such as the media given: convert it to MP4, QuickTime, WebM, or MPEG-TS"

      assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_category(StringIO.new(MATROSKA)) }.message
      assert_equal message, assert_raises(InvalidMediaType) { inference.infer_media_type(StringIO.new(MATROSKA), "tweet_video") }.message
      assert_equal "video/webm", inference.infer_media_type(StringIO.new(WEBM), "tweet_video")
    end

    def test_a_matroska_video_in_a_file_whose_name_names_no_type_is_refused
      in_file("", MATROSKA) { |path| assert_raises(InvalidMediaType) { inference.infer_media_type(path, "tweet_video") } }
    end

    def test_a_file_whose_extension_names_a_type_is_that_type_whatever_it_begins_with
      in_file(".mp4", MATROSKA) { |path| assert_equal "video/mp4", inference.infer_media_type(path, "tweet_video") }
    end

    private

    # Write bytes to a file of an extension, and yield its path
    def in_file(extension, bytes)
      Tempfile.create(["clip", extension]) do |file|
        file.binmode
        file.write(bytes.ljust(64, "\x00"))
        file.flush
        yield file.path
      end
    end
  end
end
