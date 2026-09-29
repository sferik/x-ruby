# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # The contents of media given as a String where its path belongs are refused, rather than looked for as a file
  class SourceContentsTest < Minitest::Test
    cover Uploader.const_get(:Source)

    MESSAGE = "media must be a path to the media, or an IO that reads it, such as a StringIO, not the contents of the " \
      "media: a String that holds a NUL byte or a line break names no file"

    def test_the_bytes_of_an_image_are_refused_before_any_request
      error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload(File.binread("test/sample_files/sample.png"), client: Client.new) }

      assert_equal MESSAGE, error.message
      assert_not_requested :any, /x\.com/
    end

    def test_the_text_of_subtitles_is_refused
      error = assert_raises(ArgumentError) { Uploader::MediaUpload.chunked_upload(File.read("test/sample_files/sample.srt"), client: Client.new) }

      assert_equal MESSAGE, error.message
    end

    def test_a_string_that_holds_a_nul_byte_or_a_line_break_is_refused
      ["cat\x00.png", "cat\n.png", "\xFF\xD8\x00\xFF".dup.force_encoding(Encoding::UTF_8)].each do |media|
        assert_equal MESSAGE, assert_raises(ArgumentError, media.inspect) { Uploader.const_get(:Source).for(media) }.message
      end
    end

    def test_a_path_of_any_other_bytes_is_a_path
      assert_equal "cat\r\t é.png", Uploader.const_get(:Source).for("cat\r\t é.png").name
    end
  end
end
