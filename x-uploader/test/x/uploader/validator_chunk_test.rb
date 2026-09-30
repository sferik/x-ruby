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

    def test_the_chunk_size_derived_for_a_file_of_the_most_the_api_takes_fits_the_segments_it_numbers
      with_file(16 * 1024**3) do |path|
        chunk_size = Uploader.const_get(:Validator).validate_segments!(source(path), nil)

        assert_equal 1_717_987, chunk_size
        assert_operator chunk_size, :<, MAX_CHUNK
      end
    end

    def test_a_video_of_the_most_the_api_takes_of_an_upload_is_taken_and_a_byte_more_refused
      validator = Uploader.const_get(:Validator)

      with_file(16 * 1024**3) { |path| assert_nil validator.validate_size!(source(path), "amplify_video") }
      with_file((16 * 1024**3) + 1) do |path|
        error = assert_raises(InvalidMedia) { validator.validate_size!(source(path), "amplify_video") }

        assert_equal "#{path} is 17179869185 bytes, more than the 17179869184 bytes the API takes of amplify_video media", error.message
      end
    end

    def test_a_chunk_size_of_the_largest_segment_the_api_takes_is_taken
      assert_nil Uploader.const_get(:Validator).validate_chunks!(chunk_size: MAX_CHUNK, concurrency: 1)
    end

    def test_a_chunk_size_larger_than_the_largest_segment_the_api_takes_is_refused
      error = assert_raises(ArgumentError) { Uploader.const_get(:Validator).validate_chunks!(chunk_size: MAX_CHUNK + 1, concurrency: 1) }

      assert_equal "chunk_size must be at most 5242880, the bytes of a segment the API takes, not 5242881", error.message
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
