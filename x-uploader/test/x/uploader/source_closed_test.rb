# frozen_string_literal: true

require "stringio"
require "tempfile"
require_relative "../../test_helper"
require "x/uploader/source"

module X
  class SourceClosedTest < Minitest::Test
    cover Uploader.const_get(:Source)

    def test_a_file_that_was_closed_is_read_from_its_path
      File.open("test/sample_files/sample.png", "rb") { |file| @file = file }
      source = Uploader.const_get(:Source).for(@file)

      assert_equal [File.binread("test/sample_files/sample.png"), "png"], [source.content, source.extension]
    end

    def test_a_tempfile_that_was_closed_is_read_from_its_path
      tempfile = Tempfile.new(%w[source .gif])
      tempfile.write("GIF89a")
      tempfile.close

      assert_equal "GIF89a", Uploader.const_get(:Source).for(tempfile).content
    ensure
      tempfile&.close!
    end

    def test_an_io_that_cannot_say_whether_it_was_closed_is_read_as_one_that_is_open
      reader = StringIO.new("GIF89a")
      def reader.to_path = nil
      reader.singleton_class.undef_method(:closed?)

      assert_equal "GIF89a", Uploader.const_get(:Source).for(reader).content
    end
  end
end
