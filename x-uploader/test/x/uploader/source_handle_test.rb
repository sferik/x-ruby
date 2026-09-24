# frozen_string_literal: true

require "tempfile"
require_relative "../../test_helper"
require "x/uploader/source"

module X
  # An IO open on a file is read through the IO, whatever its name leads to
  class SourceHandleTest < Minitest::Test
    cover Uploader.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    def source_for(media) = Uploader.const_get(:Source).for(media)

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

        assert_equal [nil, false, "the media given"], [source.name, source.named?, source.description]
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

    def test_the_io_is_left_where_it_was_when_a_read_fails
      File.open(PNG, "rb") do |file|
        file.seek(10)
        source = source_for(file)

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

    def test_the_chunks_read_through_one_io_in_turn
      File.open(PNG, "rb") do |file|
        source = source_for(file)
        chunks = Array.new(8) { |index| Thread.new { source.read(16, index * 16) } }.map(&:value)

        assert_equal File.binread(PNG, 128), chunks.join
      end
    end
  end
end
