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

      # Valid media category values
      MEDIA_CATEGORIES = %w[amplify_video dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].freeze

      # Validate that a file path exists
      #
      # @api private
      # @param file_path [String] the file path to validate
      # @return [void]
      # @raise [Errno::ENOENT] if the file does not exist
      # @example Validate a file path
      #   Uploader::Validator.validate_file_path!("image.png")
      def validate_file_path!(file_path)
        raise Errno::ENOENT, file_path unless File.exist?(file_path)
      end

      # Validate that a file has one of the extensions an upload supports
      #
      # @api private
      # @param file_path [String] the file path to validate
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

      # Validate the chunk size and concurrency of a chunked upload
      #
      # @api private
      # @param chunk_size_mb [Float, Integer] the size of each chunk in megabytes, which must be positive
      # @param concurrency [Integer] the number of chunks uploaded at once, which must be at least one
      # @return [void]
      # @raise [ArgumentError] if the chunk size is not positive or the concurrency is less than one
      # @example Validate the options of a chunked upload
      #   Uploader::Validator.validate_chunks!(chunk_size_mb: 4, concurrency: 2)
      def validate_chunks!(chunk_size_mb:, concurrency:)
        raise ArgumentError, "chunk_size_mb must be positive, not #{chunk_size_mb}" unless chunk_size_mb.positive?
        raise ArgumentError, "concurrency must be an Integer of at least 1, not #{concurrency}" unless concurrency.integer? && concurrency.positive?
      end

      # Validate that a media category is valid
      #
      # @api private
      # @param media_category [String] the media category to validate
      # @return [void]
      # @raise [ArgumentError] if the media category is invalid
      # @example Validate a media category
      #   Uploader::Validator.validate_media_category!("tweet_image")
      def validate_media_category!(media_category)
        return if MEDIA_CATEGORIES.include?(media_category.downcase)

        raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
      end
    end
  end
end
