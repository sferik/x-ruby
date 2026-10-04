# frozen_string_literal: true

require "tempfile"
require_relative "../../test_helper"
require "x/uploads/source"

module X
  # An IO open on a file is read through the IO, whatever its name leads to
  class SourceHandleTest < Minitest::Test
    cover Uploads.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    def source_for(media) = Uploads.const_get(:Source).for(media)

    # Copy the sample PNG into a Tempfile named for it, unlink the path of the Tempfile, and yield it
    def in_unlinked_png
      Tempfile.create(%w[source .png]) do |file|
        file.binmode
        file.write(File.binread(PNG))
        File.unlink(file.path)
        yield file
      end
    end

    def test_an_unlinked_tempfile_is_read_through_the_io
      skip "a file that is open cannot be unlinked on Windows" if Gem.win_platform?
      in_unlinked_png do |file|
        source = source_for(file)

        assert_equal [true, true, File.size(PNG), "png"], [source.exist?, source.readable?, source.size, source.extension]
        assert_equal File.binread(PNG), source.content
      end
    end

    def test_an_anonymous_tempfile_names_no_file
      Tempfile.create(anonymous: true) do |file|
        file.write("GIF89a")
        source = source_for(file)

        assert_equal [nil, "the media given"], [source.name, source.description]
        assert_equal [true, 6, "GIF89a"], [source.readable?, source.size, source.sniff]
      end
    end

    def test_the_io_is_read_from_the_start_of_the_file_and_left_where_it_was
      File.open(PNG, "rb") do |file|
        file.seek(10)
        source = source_for(file)

        assert_equal [File.binread(PNG, 4, 1), File.binread(PNG, 512)], [source.read(4, 1), source.sniff]
        assert_equal 10, file.pos
      end
    end

    def test_the_io_is_read_at_the_offset_without_moving_it
      File.open(PNG, "rb") do |file|
        file.seek(10)
        source = source_for(file)

        file.stub(:seek, ->(*) { flunk "seeked" }) do
          assert_equal File.binread(PNG, 4, 1), source.read(4, 1)
        end
        assert_equal 10, file.pos
      end
    end

    def test_a_read_past_the_end_of_the_file_reads_nothing
      File.open(PNG, "rb") do |file|
        source = source_for(file)

        assert_equal ["", File.binread(PNG, 8, File.size(PNG) - 8)], [source.read(4, File.size(PNG)), source.read(16, File.size(PNG) - 8)]
      end
    end

    # An IO that cannot pread, as one on Windows cannot
    def without_pread(file)
      file.define_singleton_method(:respond_to?) { |name, include_all = false| !name.equal?(:pread) && super(name, include_all) }
      file.define_singleton_method(:pread) { |*| raise NotImplementedError, "pread() function is unimplemented on this machine" }
      file
    end

    def test_an_io_that_cannot_pread_is_read_from_the_offset_and_left_where_it_was
      File.open(PNG, "rb") do |file|
        file.seek(10)
        source = source_for(without_pread(file))

        assert_equal [File.binread(PNG, 4, 1), "", 10], [source.read(4, 1), source.read(4, File.size(PNG)), file.pos]
      end
    end

    def test_an_io_that_cannot_pread_is_left_where_it_was_when_a_read_fails
      File.open(PNG, "rb") do |file|
        file.seek(10)
        source = source_for(without_pread(file))

        file.stub(:read, ->(_length) { raise IOError, "closed stream" }) do
          assert_raises(IOError) { source.read(4, 1) }
        end

        assert_equal 10, file.pos
      end
    end

    def test_an_io_open_in_text_mode_is_read_as_bytes
      File.open(PNG, "r") do |file|
        content = source_for(file).content

        assert_equal [Encoding::BINARY, File.binread(PNG)], [content.encoding, content]
      end
    end

    def test_the_signature_of_an_empty_file_is_empty
      Tempfile.create("source") do |file|
        assert_empty source_for(file).sniff
      end
    end

    def test_an_io_open_on_a_directory_cannot_be_read
      skip "a directory cannot be opened as a file on Windows" if Gem.win_platform?

      File.open("test/sample_files") do |directory|
        source = source_for(directory)

        assert_equal [nil, true, false], [source.name, source.exist?, source.readable?]
      end
    end
  end
end
