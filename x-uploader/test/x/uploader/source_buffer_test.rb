# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"
require "x/uploader/source"
require "x/uploader/media_upload"

module X
  # An IO that is not open on a file is read from its start when it can seek, and given back at the position it held,
  # and read from where it is to its end when it cannot
  class SourceBufferTest < Minitest::Test
    cover Uploader.const_get(:Source)
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Gif)

    PNG = "test/sample_files/sample.png"

    def source_for(media) = Uploader.const_get(:Source).for(media)

    def test_a_string_io_is_read_from_its_start_and_given_back_at_its_position
      io = StringIO.new("0123456789")
      io.seek(2)

      assert_equal "0123456789", source_for(io).content
      assert_equal 2, io.pos
    end

    def test_a_string_io_that_was_written_to_is_read_whole
      io = StringIO.new
      io.write("GIF89a")

      assert_equal "GIF89a", source_for(io).content
      assert_predicate io, :eof?
    end

    def test_a_pipe_is_read_from_where_it_is
      reader, writer = IO.pipe
      writer.write("0123456789")
      writer.close
      reader.read(2)

      assert_equal "23456789", source_for(reader).content
    ensure
      reader&.close
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
      inferring = inference

      assert_equal "tweet_image", inferring.infer_media_category(io)
      assert_equal "image/png", inferring.infer_media_type(io, "tweet_image")
      refute inferring.chunked_upload?(io, "tweet_gif")
      refute Uploader.const_get(:Gif).animated?(io)
      assert_equal [0, File.binread(PNG)], [io.pos, io.read]
    end
  end
end
