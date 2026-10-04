# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/source"

module X
  # The chunks of an IO that cannot pread, read at once by many threads, are each read from the offset of its own
  class SourceHandleThreadsTest < Minitest::Test
    cover Uploads.const_get(:Source)

    PNG = "test/sample_files/sample.png"

    # Make a file answer as an IO that cannot pread, as a pipe or an IO on Windows does
    def without_pread(file)
      file.define_singleton_method(:respond_to?) { |name, include_all = false| !name.equal?(:pread) && super(name, include_all) }
      file.define_singleton_method(:pread) { |*| raise NotImplementedError, "pread() function is unimplemented on this machine" }
      file
    end

    # Let another thread run between a seek of the file and the read after it, as one may at any time
    def passing_after_seek(file)
      file.define_singleton_method(:seek) { |*arguments| super(*arguments).tap { Thread.pass } }
      file
    end

    def test_the_chunks_of_an_io_that_cannot_pread_read_through_it_in_turn
      File.open(PNG, "rb") do |file|
        source = Uploads.const_get(:Source).for(passing_after_seek(without_pread(file)))
        chunks = Array.new(8) { |index| Thread.new { source.read(16, index * 16) } }.map(&:value)

        assert_equal File.binread(PNG, 128), chunks.join
      end
    end
  end
end
