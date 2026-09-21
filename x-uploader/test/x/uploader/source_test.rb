# frozen_string_literal: true

require "pathname"
require "stringio"
require "tempfile"
require_relative "../../test_helper"
require "x/uploader/source"

module X
  class SourceTest < Minitest::Test
    cover Uploader.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    def test_the_source_of_a_source_is_that_source
      source = Uploader.const_get(:Source).for(PNG)

      assert_same source, Uploader.const_get(:Source).for(source)
    end

    def test_a_string_and_a_pathname_name_the_file_they_are_read_from
      [PNG, Pathname(PNG)].each do |path|
        source = Uploader.const_get(:Source).for(path)

        assert_equal [PNG, true, PNG, "png"], [source.name, source.named?, source.description, source.extension]
      end
    end

    def test_an_io_open_on_a_file_is_read_from_that_file
      File.open(PNG, "rb") do |file|
        source = Uploader.const_get(:Source).for(file)

        assert_equal [PNG, true], [source.name, source.named?]
        assert_equal File.size(PNG), source.size
      end
    end

    def test_an_io_open_on_a_file_is_flushed_so_the_upload_reads_what_it_has_written
      Tempfile.create(%w[source .png]) do |file|
        file.write("written")
        source = Uploader.const_get(:Source).for(file)

        assert_equal "written", source.content
        assert_equal 7, source.size
      end
    end

    def test_a_file_is_read_by_position_from_any_thread
      source = Uploader.const_get(:Source).for(PNG)

      assert_equal File.binread(PNG), source.content
      assert_equal File.binread(PNG, 4, 1), source.read(4, 1)
      assert_equal File.binread(PNG, 64), source.sniff
    end

    def test_a_file_that_is_there_exists_and_can_be_read
      source = Uploader.const_get(:Source).for(PNG)

      assert_equal [true, true], [source.exist?, source.readable?]
    end

    def test_a_file_that_is_not_there_neither_exists_nor_can_be_read
      source = Uploader.const_get(:Source).for("nope.png")

      assert_equal [false, false], [source.exist?, source.readable?]
    end

    def test_a_directory_exists_but_cannot_be_read
      source = Uploader.const_get(:Source).for("test/sample_files")

      assert_equal [true, false], [source.exist?, source.readable?]
    end

    def test_an_io_that_names_no_file_is_read_to_its_end_and_held
      source = Uploader.const_get(:Source).for(StringIO.new("0123456789"))

      assert_equal [nil, false, "the media given", ""], [source.name, source.named?, source.description, source.extension]
      assert_equal [true, true, 10], [source.exist?, source.readable?, source.size]
      assert_equal "0123456789", source.content
      assert_equal "1234", source.read(4, 1)
    end

    def test_media_held_in_memory_is_read_as_bytes
      source = Uploader.const_get(:Source).for(StringIO.new("héllo"))

      assert_equal Encoding::BINARY, source.content.encoding
      assert_equal 6, source.size
    end

    def test_the_signature_of_media_shorter_than_the_bytes_it_is_read_from
      assert_equal "GIF89a", Uploader.const_get(:Source).for(StringIO.new("GIF89a")).sniff
    end

    def test_the_signature_of_empty_media_is_empty
      Tempfile.create("source") do |file|
        assert_empty Uploader.const_get(:Source).for(file.path).sniff
      end
    end

    def test_an_io_that_reads_nothing_is_empty
      reader = Object.new
      def reader.read = nil

      assert_equal 0, Uploader.const_get(:Source).for(reader).size
    end

    def test_media_that_is_neither_a_path_nor_an_io_is_refused
      error = assert_raises(ArgumentError) { Uploader.const_get(:Source).for(42) }

      assert_equal "media must be a path or an IO that reads one, not Integer", error.message
    end
  end
end
