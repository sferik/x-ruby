# frozen_string_literal: true

require "stringio"
require "timeout"
require_relative "../../test_helper"
require "x/uploads/source"

module X
  # What an upload reads of its media before a request raises InvalidMedia when the system refuses the read, and a
  # chunk, which is read once the upload is initialized, raises the error of the system
  class SourceSystemErrorTest < Minitest::Test
    cover Uploads.const_get(:Source)

    PNG = "test/sample_files/sample.png"
    MISSING = "nope.png"

    def source_for(media) = Uploads.const_get(:Source).for(media)

    # An IO that is not open on a file, whose read the system refuses
    def refusing_to_read(error)
      Object.new.tap { |io| io.define_singleton_method(:read) { raise error } }
    end

    # A File open on the sample PNG that the system refuses to read by position, with the source that reads it
    def refusing_to_pread(error)
      File.open(PNG, "rb") do |file|
        file.define_singleton_method(:pread) { |*| raise error }
        yield Uploads.const_get(:Source).for(file)
      end
    end

    # The reason alone, as "Input/output error", which the system gives for the error of a class
    def assert_cannot_be_read(description, cause, reason = cause.new.message, &)
      error = assert_raises(InvalidMedia, &)

      assert_equal "#{description} cannot be read: #{reason}", error.message
      assert_instance_of cause, error.cause
    end

    def test_an_io_the_system_refuses_to_read_cannot_be_read
      assert_cannot_be_read("the media given", Errno::EIO) { source_for(refusing_to_read(Errno::EIO)) }
    end

    def test_an_io_that_can_seek_is_given_back_at_its_position_when_the_system_refuses_to_read_it
      io = StringIO.new("0123456789")
      io.seek(4)
      io.define_singleton_method(:read) { raise Errno::EIO }

      assert_cannot_be_read("the media given", Errno::EIO) { source_for(io) }
      assert_equal 4, io.pos
    end

    def test_an_io_the_system_cannot_say_what_it_is_open_on_cannot_be_read
      File.open(PNG, "rb") do |file|
        file.stub(:stat, -> { raise Errno::EBADF }) do
          assert_cannot_be_read("the media given", Errno::EBADF) { source_for(file) }
        end
      end
    end

    def test_the_signature_of_a_file_the_system_refuses_to_read_cannot_be_read
      assert_cannot_be_read(MISSING, Errno::ENOENT) { source_for(MISSING).sniff }
    end

    def test_the_size_of_a_file_the_system_refuses_to_read_cannot_be_read
      assert_cannot_be_read(MISSING, Errno::ENOENT) { source_for(MISSING).size }
    end

    def test_the_whole_of_a_file_the_system_refuses_to_read_cannot_be_read
      assert_cannot_be_read(MISSING, Errno::ENOENT) { source_for(MISSING).content }
    end

    def test_a_chunk_of_a_file_the_system_refuses_to_read_raises_the_error_of_the_system
      assert_raises(Errno::ENOENT) { source_for(MISSING).read(4, 0) }
    end

    def test_an_open_file_the_system_cannot_say_what_it_is_open_on_cannot_be_read
      File.open(PNG, "rb") do |file|
        source = source_for(file)

        file.stub(:stat, -> { raise Errno::EBADF }) { assert_cannot_be_read(PNG, Errno::EBADF) { source.readable? } }
      end
    end

    def test_the_size_of_an_open_file_the_system_refuses_to_read_cannot_be_read
      File.open(PNG, "rb") do |file|
        source = source_for(file)

        file.stub(:size, -> { raise Errno::EIO }) { assert_cannot_be_read(PNG, Errno::EIO) { source.size } }
      end
    end

    def test_the_whole_of_an_open_file_the_system_refuses_to_read_cannot_be_read
      refusing_to_pread(Errno::EIO) { |source| assert_cannot_be_read(PNG, Errno::EIO) { source.content } }
    end

    def test_a_chunk_of_an_open_file_the_system_refuses_to_read_raises_the_error_of_the_system
      refusing_to_pread(Errno::EIO) { |source| assert_raises(Errno::EIO) { source.read(4, 0) } }
    end

    def test_the_reason_of_an_error_of_the_system_is_given_without_the_function_and_the_path_ruby_adds
      error = assert_raises(InvalidMedia) { source_for(MISSING).size }

      assert_equal "nope.png cannot be read: No such file or directory", error.message
      assert_match(/ @ \w+ - nope\.png\z/, error.cause.message)
    end

    def test_an_error_of_the_system_that_holds_no_number_gives_its_message
      io = refusing_to_read(SystemCallError.new("refused"))

      assert_cannot_be_read("the media given", SystemCallError, "unknown error - refused") { source_for(io) }
    end

    def test_an_error_of_the_system_whose_number_ruby_does_not_know_gives_the_reason_of_the_system
      error = SystemCallError.new("refused", 99_999)

      assert_cannot_be_read("the media given", SystemCallError, SystemCallError.new(99_999).message) do
        source_for(refusing_to_read(error))
      end
    end

    def test_an_io_error_gives_its_message
      refusing_to_pread(IOError.new("stream closed in another thread")) do |source|
        assert_cannot_be_read(PNG, IOError, "stream closed in another thread") { source.sniff }
      end
    end

    def test_an_open_file_whose_read_times_out_cannot_be_read
      refusing_to_pread(IO::TimeoutError.new("Blocking operation timed out!")) do |source|
        assert_cannot_be_read(PNG, IO::TimeoutError, "Blocking operation timed out!") { source.content }
      end
    end

    def test_a_timeout_around_the_upload_is_raised_as_it_is
      refusing_to_pread(Timeout::Error) { |source| assert_raises(Timeout::Error) { source.sniff } }
    end

    def test_an_interrupt_is_raised_as_it_is
      refusing_to_pread(Interrupt) { |source| assert_raises(Interrupt) { source.sniff } }
    end
  end
end
