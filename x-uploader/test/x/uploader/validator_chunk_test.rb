# frozen_string_literal: true

require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/validator"

module X
  class ValidatorChunkTest < Minitest::Test
    cover Uploader.const_get(:Validator)

    BYTES_PER_MB = Uploader.const_get(:Validator)::BYTES_PER_MB
    # The most bytes a segment of an upload in chunks holds
    MAX_CHUNK = Uploader.const_get(:Validator)::MAX_CHUNK

    def test_the_chunk_size_derived_for_a_file_of_the_largest_segments_the_api_numbers_is_the_largest_segment
      with_file(10_000 * MAX_CHUNK) do |path|
        assert_equal MAX_CHUNK, Uploader.const_get(:Validator).validate_segments!(source(path), nil)
      end
    end

    def test_a_file_larger_than_the_largest_segments_the_api_numbers_is_refused_for_the_chunk_size_derived
      with_file((10_000 * MAX_CHUNK) + 1) do |path|
        error = assert_raises(InvalidMedia) { Uploader.const_get(:Validator).validate_segments!(source(path), nil) }

        assert_equal "#{path} is 52428800001 bytes, more than the 10000 segments of 5242880 bytes the API takes", error.message
      end
    end

    def test_a_chunk_size_of_the_largest_segment_the_api_takes_is_taken
      assert_nil Uploader.const_get(:Validator).validate_chunks!(chunk_size_mb: 5, concurrency: 1)
    end

    def test_a_chunk_size_larger_than_the_largest_segment_the_api_takes_is_refused
      error = assert_raises(ArgumentError) { Uploader.const_get(:Validator).validate_chunks!(chunk_size_mb: (MAX_CHUNK + 1.0) / BYTES_PER_MB, concurrency: 1) }

      assert_equal "chunk_size_mb must be at most 5, the megabytes of a segment the API takes, not #{(MAX_CHUNK + 1.0) / BYTES_PER_MB}", error.message
    end

    def test_the_largest_segment_is_five_megabytes
      assert_equal 5 * 1_048_576, MAX_CHUNK
    end

    private

    # The media an upload reads, which the validator takes in place of a path
    def source(file_path) = Uploader.const_get(:Source).for(file_path)

    # An empty file read as a size, which costs no disk, as a file of tens of gigabytes would
    def with_file(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.write(path, "")
        File.stub(:size, size) { yield path }
      end
    end
  end
end
