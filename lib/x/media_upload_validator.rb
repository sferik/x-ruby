module X
  # Validates media upload parameters
  # @api public
  module MediaUploadValidator
    module_function

    # Valid media category values
    MEDIA_CATEGORIES = %w[dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].freeze

    # Validate that a file path exists
    #
    # @api private
    # @param file_path [String] the file path to validate
    # @return [void]
    # @raise [RuntimeError] if the file does not exist
    # @example Validate a file path
    #   MediaUploadValidator.validate_file_path!(file_path: "image.png")
    def validate_file_path!(file_path:)
      raise "File not found: #{file_path}" unless File.exist?(file_path)
    end

    # Validate that a media category is valid
    #
    # @api private
    # @param media_category [String] the media category to validate
    # @return [void]
    # @raise [ArgumentError] if the media category is invalid
    # @example Validate a media category
    #   MediaUploadValidator.validate_media_category!(media_category: "tweet_image")
    def validate_media_category!(media_category:)
      return if MEDIA_CATEGORIES.include?(media_category.downcase)

      raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
    end
  end
end
