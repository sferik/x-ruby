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
      assert_nil Uploader::Validator.validate_media_category!("tweet_image")
    end

    def test_validate_amplify_video
      assert_nil Uploader::Validator.validate_media_category!("amplify_video")
    end

    def test_validate_media_category_ignores_case
      assert_nil Uploader::Validator.validate_media_category!("TWEET_IMAGE")
    end

    def test_validate_media_category_raises_for_invalid_category
      error = assert_raises(ArgumentError) { Uploader::Validator.validate_media_category!("bogus") }

      assert_equal "Invalid media_category: bogus. Valid values: amplify_video, dm_gif, dm_image, dm_video, subtitles, tweet_gif, " \
        "tweet_image, tweet_video", error.message
    end
  end
end
