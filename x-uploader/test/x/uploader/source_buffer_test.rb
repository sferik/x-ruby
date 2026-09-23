# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"
require "x/uploader/source"
require "x/uploader/media_upload"

module X
  # An IO that is not open on a file is read to its end, and given back at the position it held when it can seek
  class SourceBufferTest < Minitest::Test
    cover Uploader.const_get(:Source)
    cover Uploader::MediaUpload
    cover Uploader::Gif

    PNG = "test/sample_files/sample.png"

    def source_for(media) = Uploader.const_get(:Source).for(media)

    def test_a_string_io_is_read_from_its_position_and_given_back_there
      io = StringIO.new("0123456789")
      io.seek(2)

      assert_equal "23456789", source_for(io).content
      assert_equal 2, io.pos
    end

    def test_an_io_that_cannot_seek_is_read_to_its_end
      reader, writer = IO.pipe
      writer.write("GIF89a")
      writer.close

      assert_equal "GIF89a", source_for(reader).content
      assert_predicate reader, :eof?
    ensure
      reader&.close
    end

    def test_an_io_that_answers_seek_but_has_no_position_is_read_to_its_end
      io = StringIO.new("GIF89a")
      io.define_singleton_method(:pos) { raise Errno::ESPIPE }

      assert_equal "GIF89a", source_for(io).content
      assert_predicate io, :eof?
    end

    def test_the_helpers_leave_the_media_to_be_uploaded
      io = StringIO.new(File.binread(PNG))

      assert_equal "tweet_image", Uploader::MediaUpload.infer_media_category(io)
      assert_equal "image/png", Uploader::MediaUpload.infer_media_type(io, "tweet_image")
      refute Uploader::MediaUpload.chunked_upload?(io, "tweet_gif")
      refute Uploader::Gif.animated?(io)
      assert_equal [0, File.binread(PNG)], [io.pos, io.read]
    end
  end
end
