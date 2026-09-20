require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/validator"

module X
  class ValidatorTest < Minitest::Test
    cover Uploader::Validator

    def test_validate_file_path
      assert_nil Uploader::Validator.validate_file_path!("test/sample_files/sample.jpg")
    end

    def test_validate_file_path_raises_for_missing_file
      error = assert_raises(Errno::ENOENT) { Uploader::Validator.validate_file_path!("bad/path") }

      assert_equal "No such file or directory - bad/path", error.message
    end

    def test_validate_file_path_of_a_pathname
      assert_nil Uploader::Validator.validate_file_path!(Pathname("test/sample_files/sample.jpg"))
    end

    def test_validate_file_path_raises_for_a_missing_pathname
      error = assert_raises(Errno::ENOENT) { Uploader::Validator.validate_file_path!(Pathname("bad/path")) }

      assert_equal "No such file or directory - bad/path", error.message
    end

    def test_validate_extension
      assert_nil Uploader::Validator.validate_extension!("avatar.png", %w[jpg png])
    end

    def test_validate_extension_ignores_case
      assert_nil Uploader::Validator.validate_extension!(Pathname("AVATAR.PNG"), %w[jpg png])
    end

    def test_validate_extension_raises_for_an_unsupported_extension
      error = assert_raises(Uploader::InvalidMediaType) { Uploader::Validator.validate_extension!("clip.MP4", %w[jpg png]) }

      assert_equal "Unsupported file type: mp4. Supported types: jpg, png", error.message
    end

    def test_validate_chunks
      assert_nil Uploader::Validator.validate_chunks!(chunk_size_mb: 0.0625, concurrency: 1)
    end

    def test_validate_chunks_takes_the_chunk_size_of_a_caller_who_named_none
      assert_nil Uploader::Validator.validate_chunks!(chunk_size_mb: nil, concurrency: 1)
    end

    def test_validate_chunks_raises_for_a_chunk_size_that_is_not_positive
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_chunks!(chunk_size_mb: 0, concurrency: 1) }

      assert_equal "chunk_size_mb must be positive, not 0", error.message
      assert_raises(ArgumentError) { Uploader::Validator.validate_chunks!(chunk_size_mb: -1, concurrency: 1) }
    end

    def test_validate_chunks_raises_for_a_concurrency_less_than_one
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_chunks!(chunk_size_mb: 1, concurrency: 0) }

      assert_equal "concurrency must be an Integer of at least 1, not 0", error.message
      assert_raises(ArgumentError) { Uploader::Validator.validate_chunks!(chunk_size_mb: 1, concurrency: -1) }
    end

    def test_validate_chunks_raises_for_a_concurrency_that_is_not_an_integer
      assert_raises(ArgumentError) { Uploader::Validator.validate_chunks!(chunk_size_mb: 1, concurrency: 2.5) }
    end

    def test_validate_media_category
      assert_equal "tweet_image", Uploader::Validator.validate_media_category!("tweet_image")
    end

    def test_validate_amplify_video
      assert_equal "amplify_video", Uploader::Validator.validate_media_category!("amplify_video")
    end

    def test_validate_media_category_ignores_case
      assert_equal "tweet_image", Uploader::Validator.validate_media_category!("TWEET_IMAGE")
    end

    def test_validate_media_category_takes_a_symbol
      assert_equal %w[tweet_video tweet_image], [:tweet_video, :TWEET_IMAGE].map { |category| Uploader::Validator.validate_media_category!(category) }
    end

    def test_validate_media_category_raises_for_a_symbol_that_names_no_category
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_media_category!(:bogus) }

      assert_includes error.message, "Invalid media_category: bogus"
    end

    def test_validate_media_category_raises_for_invalid_category
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_media_category!("bogus") }

      assert_equal "Invalid media_category: bogus. Valid values: amplify_video, dm_gif, dm_image, dm_video, subtitles, tweet_gif, " \
        "tweet_image, tweet_video", error.message
    end
  end

  class ValidatorUploadTest < Minitest::Test
    cover Uploader::Validator

    BYTES_PER_MB = Uploader::Validator::BYTES_PER_MB
    # A file larger than the megabyte chunks every upload in chunks once used, of 1,100 of them
    LARGE_FILE_BYTES = 1100 * BYTES_PER_MB

    def test_validate_alt_text
      assert_nil Uploader::Validator.validate_alt_text!("A cat asleep on a keyboard")
      assert_nil Uploader::Validator.validate_alt_text!("A")
      assert_nil Uploader::Validator.validate_alt_text!("A" * 1000)
    end

    def test_media_described_with_no_alt_text_is_valid
      assert_nil Uploader::Validator.validate_alt_text!(nil)
    end

    def test_validate_alt_text_raises_for_empty_alt_text
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_alt_text!("") }

      assert_equal "alt_text must be 1 to 1000 characters, not 0", error.message
    end

    def test_validate_alt_text_raises_for_alt_text_longer_than_the_api_takes
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_alt_text!("A" * 1001) }

      assert_equal "alt_text must be 1 to 1000 characters, not 1001", error.message
    end

    def test_a_chunk_size_of_a_megabyte_is_derived_for_a_file_the_api_numbers_the_segments_of
      with_file(BYTES_PER_MB + 1) do |path|
        assert_equal BYTES_PER_MB, Uploader::Validator.validate_segments!(path, nil)
      end
    end

    def test_the_chunk_size_derived_for_a_large_file_uploads_it_in_the_segments_the_api_numbers
      with_file(LARGE_FILE_BYTES) do |path|
        chunk_size = Uploader::Validator.validate_segments!(path, nil)

        assert_equal 1_153_434, chunk_size
        assert_operator (LARGE_FILE_BYTES.to_f / chunk_size).ceil, :<=, 1000
      end
    end

    def test_a_chunk_size_given_is_taken_in_megabytes_and_rounded_up_to_a_whole_byte
      with_file(4000) do |path|
        assert_equal [2_097_152, 1001], [Uploader::Validator.validate_segments!(path, 2), Uploader::Validator.validate_segments!(path, 1000.5 / BYTES_PER_MB)]
      end
    end

    def test_a_chunk_size_that_uploads_a_file_in_the_segments_the_api_numbers_exactly
      with_file(1000) do |path|
        assert_equal 1, Uploader::Validator.validate_segments!(path, 1.0 / BYTES_PER_MB)
      end
    end

    def test_a_chunk_size_that_would_upload_a_file_in_more_segments_than_the_api_numbers
      with_file(1001) do |path|
        error = assert_raises(ArgumentError) { Uploader::Validator.validate_segments!(path, 1.0 / BYTES_PER_MB) }

        assert_includes error.message, "uploads 1001 bytes in more than the 1000 segments the API numbers"
      end
    end

    def test_a_chunk_size_of_a_megabyte_would_upload_a_large_file_in_more_segments_than_the_api_numbers
      with_file(LARGE_FILE_BYTES) do |path|
        error = assert_raises(ArgumentError) { Uploader::Validator.validate_segments!(path, 1) }

        assert_equal "chunk_size_mb of 1 uploads #{LARGE_FILE_BYTES} bytes in more than the 1000 segments the API numbers", error.message
      end
    end

    def test_validate_upload_gives_the_media_category_in_the_case_the_api_takes
      assert_equal "tweet_image", Uploader::Validator.validate_upload!("test/sample_files/sample.png", :TWEET_IMAGE,
        alt_text: "A pixel", chunk_size_mb: nil, concurrency: 4)
    end

    def test_validate_upload_validates_the_file_the_alt_text_and_the_chunk_options
      assert_raises(Errno::ENOENT) { validate_upload("nope.png") }
      assert_raises(ArgumentError) { validate_upload("test/sample_files/sample.png", alt_text: "") }
      assert_raises(ArgumentError) { validate_upload("test/sample_files/sample.png", chunk_size_mb: 0) }
      assert_raises(ArgumentError) { validate_upload("test/sample_files/sample.png", concurrency: 0) }
      assert_raises(ArgumentError) { validate_upload("test/sample_files/sample.png", media_category: "bogus") }
    end

    private

    def validate_upload(file_path, media_category: "tweet_image", alt_text: nil, chunk_size_mb: nil, concurrency: 4)
      Uploader::Validator.validate_upload!(file_path, media_category, alt_text:, chunk_size_mb:, concurrency:)
    end

    # A sparse file of a size, which costs no disk of its own
    def with_file(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.write(path, "")
        File.truncate(path, size)
        yield path
      end
    end
  end
end
