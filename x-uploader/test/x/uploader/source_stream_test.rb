# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/source"

module X
  # An IO is read by position only when it is open on a file, and any other, such as $stdin reading a pipe, is read
  # to its end and held
  class SourceStreamTest < Minitest::Test
    cover Uploader.const_get(:Source)

    def test_an_io_whose_path_names_a_pipe_is_read_to_its_end_and_held_as_stdin_is
      reader, writer = IO.pipe
      writer.write("GIF89a")
      writer.close
      reader.define_singleton_method(:to_path) { "<STDIN>" }
      source = Uploader.const_get(:Source).for(reader)

      assert_equal [nil, 6, "GIF89a"], [source.name, source.size, source.content]
      assert_predicate reader, :binmode?
    ensure
      reader&.close
    end

    def test_a_file_open_on_a_pipe_is_read_in_binary_mode
      reader, writer = IO.pipe
      writer.write("\x89PNG\r\n\x1A\n".b)
      writer.close
      pipe = File.for_fd(reader.fileno, "r", autoclose: false)

      assert_equal "\x89PNG\r\n\x1A\n".b, Uploader.const_get(:Source).for(pipe).content
      assert_predicate pipe, :binmode?
    ensure
      reader&.close
    end

    def test_an_io_open_on_a_file_it_names_no_path_of_is_read_to_its_end_and_held
      File.open("test/sample_files/sample.png", "rb") do |file|
        io = IO.for_fd(file.fileno, "rb", autoclose: false)
        source = Uploader.const_get(:Source).for(io)

        assert_equal [nil, File.binread("test/sample_files/sample.png")], [source.name, source.content]
      end
    end

    def test_an_io_open_on_a_directory_exists_but_cannot_be_read
      skip "a directory cannot be opened as a file on Windows" if Gem.win_platform?

      File.open("test/sample_files") do |directory|
        source = Uploader.const_get(:Source).for(directory)

        assert_equal [true, false], [source.exist?, source.readable?]
      end
    end
  end
end
