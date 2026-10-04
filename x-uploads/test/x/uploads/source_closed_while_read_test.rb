# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/source"

module X
  # What an upload reads before a request of a File that was closed meanwhile, as by another thread, raises
  # InvalidMedia, and a chunk, which is read once the upload is initialized, raises the error as it is
  class SourceClosedWhileReadTest < Minitest::Test
    cover Uploads.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    def source_for(media) = Uploads.const_get(:Source).for(media)

    # A File open on the sample PNG that is closed as the method named is called, with the source that reads it
    def closed_at(method)
      File.open(PNG, "rb") do |file|
        source = source_for(file)
        file.define_singleton_method(method) { |*arguments| close.then { super(*arguments) } }
        yield source
      end
    end

    def assert_cannot_be_read(description, &)
      error = assert_raises(InvalidMedia, &)

      assert_equal "#{description} cannot be read: closed stream", error.message
      assert_instance_of IOError, error.cause
    end

    def test_an_open_file_closed_before_the_system_says_what_it_is_open_on_cannot_be_read
      File.open(PNG, "rb") do |file|
        file.define_singleton_method(:stat) { close.then { super() } }

        assert_cannot_be_read("the media given") { source_for(file) }
      end
    end

    def test_an_open_file_closed_before_it_is_checked_cannot_be_read
      closed_at(:stat) { |source| assert_cannot_be_read(PNG) { source.readable? } }
    end

    def test_an_open_file_closed_before_its_size_is_read_cannot_be_read
      closed_at(:size) { |source| assert_cannot_be_read(PNG) { source.size } }
    end

    def test_an_open_file_closed_before_its_signature_is_read_cannot_be_read
      closed_at(:pread) { |source| assert_cannot_be_read(PNG) { source.sniff } }
    end

    def test_an_open_file_closed_before_the_whole_of_it_is_read_cannot_be_read
      File.open(PNG, "rb") do |file|
        source = source_for(file)
        source.size
        file.close

        assert_cannot_be_read(PNG) { source.content }
      end
    end

    def test_an_open_file_closed_by_another_thread_as_it_is_read_cannot_be_read
      File.open(PNG, "rb") do |file|
        source = source_for(file)
        file.define_singleton_method(:pread) { |*arguments| Thread.new { close }.join.then { super(*arguments) } }

        assert_cannot_be_read(PNG) { source.content }
      end
    end

    def test_a_chunk_of_an_open_file_that_was_closed_raises_the_error_as_it_is
      closed_at(:pread) { |source| assert_raises(IOError) { source.read(4, 0) } }
    end
  end
end
