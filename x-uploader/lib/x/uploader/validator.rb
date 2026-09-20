require_relative "invalid_media_type"
require_relative "utils"

module X
  module Uploader
    # Validates media upload parameters
    #
    # Internal to x-uploader: the uploaders validate their arguments with it.
    #
    # @api private
    module Validator
      extend self

      # Number of bytes per megabyte
      BYTES_PER_MB = 1_048_576
      # Greatest number of characters of alt text the API takes
      MAX_ALT_TEXT_LENGTH = 1000
      # Greatest number of segments an upload in chunks can have: the API takes a segment_index of 0 to 999, so an
      # upload in more chunks than these would fail partway, once the media uploaded so far had been billed
      MAX_SEGMENTS = 1000
      # Valid media category values
      MEDIA_CATEGORIES = %w[amplify_video dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].freeze

      # Validate the arguments of an upload, and give its media category in lowercase
      #
      # It validates everything an upload can be refused for before it sends a request, so that no media is uploaded,
      # and billed, for an upload that cannot finish.
      #
      # @api private
      # @param file_path [String, Pathname] the path to the file to upload
      # @param media_category [String, Symbol] the media category, in any case
      # @param alt_text [String, nil] the alt text of the media, or nil for media described with none
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, or nil to derive one
      # @param concurrency [Integer] the number of chunks uploaded at once, which must be at least one
      # @return [String] the media category in lowercase
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or too long, the chunk size is
      #   not positive, or the concurrency is less than one
      # @example Validate the arguments of an upload
      #   Uploader::Validator.validate_upload!("cat.jpg", :TWEET_IMAGE, alt_text: nil, chunk_size_mb: nil, concurrency: 4) # => "tweet_image"
      def validate_upload!(file_path, media_category, alt_text:, chunk_size_mb:, concurrency:)
        validate_file_path!(file_path)
        validate_alt_text!(alt_text)
        validate_chunks!(chunk_size_mb:, concurrency:)
        validate_media_category!(media_category)
      end

      # Validate that a file path exists
      #
      # @api private
      # @param file_path [String, Pathname] the file path to validate
      # @return [void]
      # @raise [Errno::ENOENT] if the file does not exist
      # @example Validate a file path
      #   Uploader::Validator.validate_file_path!("image.png")
      def validate_file_path!(file_path)
        raise Errno::ENOENT, File.path(file_path) unless File.exist?(file_path)
      end

      # Validate that a file has one of the extensions an upload supports
      #
      # @api private
      # @param file_path [String, Pathname] the file path to validate
      # @param extensions [Array<String>] the supported extensions, in lowercase and without a dot
      # @return [void]
      # @raise [InvalidMediaType] if the extension of the file is not supported
      # @example Validate the extension of a profile image
      #   Uploader::Validator.validate_extension!("avatar.png", %w[gif jpg jpeg png])
      def validate_extension!(file_path, extensions)
        extension = Utils.extension(file_path)
        return if extensions.include?(extension)

        raise InvalidMediaType, "Unsupported file type: #{extension}. Supported types: #{extensions.join(", ")}"
      end

      # Validate the alt text of an upload, of up to MAX_ALT_TEXT_LENGTH characters
      #
      # @api private
      # @param alt_text [String, nil] the alt text to validate, or nil for media described with none
      # @return [void]
      # @raise [ArgumentError] if the alt text is empty or longer than the API takes
      # @example Validate alt text
      #   Uploader::Validator.validate_alt_text!("A cat asleep on a keyboard")
      def validate_alt_text!(alt_text)
        return if alt_text.nil? || (1..MAX_ALT_TEXT_LENGTH).cover?(alt_text.length)

        raise ArgumentError, "alt_text must be 1 to #{MAX_ALT_TEXT_LENGTH} characters, not #{alt_text.length}"
      end

      # Validate the chunk size and concurrency of a chunked upload
      #
      # @api private
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, which must be positive, or
      #   nil for a chunk size derived from the file
      # @param concurrency [Integer] the number of chunks uploaded at once, which must be at least one
      # @return [void]
      # @raise [ArgumentError] if the chunk size is not positive or the concurrency is less than one
      # @example Validate the options of a chunked upload
      #   Uploader::Validator.validate_chunks!(chunk_size_mb: 4, concurrency: 2)
      def validate_chunks!(chunk_size_mb:, concurrency:)
        raise ArgumentError, "chunk_size_mb must be positive, not #{chunk_size_mb}" unless chunk_size_mb.nil? || chunk_size_mb.positive?
        raise ArgumentError, "concurrency must be an Integer of at least 1, not #{concurrency}" unless concurrency.integer? && concurrency.positive?
      end

      # The size in bytes of the chunks a file uploads in
      #
      # The API numbers no more than MAX_SEGMENTS segments, which an upload in more chunks would fail partway of.
      #
      # A chunk size of nil is derived from the size of the file: a megabyte, as every upload in chunks used, or the
      # size that uploads the file in MAX_SEGMENTS chunks, whichever is larger, so that a file of any size uploads.
      #
      # @api private
      # @param file_path [String, Pathname] the path to the file to upload
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, or nil to derive one
      # @return [Integer] the size of each chunk in bytes, rounded up to a whole byte
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if chunks of the size given would be more than the API numbers
      # @example Derive the chunk size of a video
      #   Uploader::Validator.validate_segments!("video.mp4", nil) # => 1048576
      def validate_segments!(file_path, chunk_size_mb)
        file_size = File.size(file_path)
        return [BYTES_PER_MB, (file_size.to_f / MAX_SEGMENTS).ceil].max if chunk_size_mb.nil?

        chunk_size = (chunk_size_mb * BYTES_PER_MB).ceil
        return chunk_size if file_size <= chunk_size * MAX_SEGMENTS

        raise ArgumentError, "chunk_size_mb of #{chunk_size_mb} uploads #{file_size} bytes in more than the #{MAX_SEGMENTS} segments the API numbers"
      end

      # Validate a media category, and give it in the lowercase the API takes
      #
      # @api private
      # @param media_category [String, Symbol] the media category to validate, in any case
      # @return [String] the media category in lowercase
      # @raise [ArgumentError] if the media category is invalid
      # @example Validate a media category
      #   Uploader::Validator.validate_media_category!(:TWEET_IMAGE) # => "tweet_image"
      def validate_media_category!(media_category)
        category = media_category.to_s.downcase
        return category if MEDIA_CATEGORIES.include?(category)

        raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
      end
    end
    private_constant :Validator
  end
end
