module X
  module MediaUploadValidator
    module_function

    MEDIA_CATEGORIES = %w[dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].freeze

    def validate_file_path!(file_path:)
      raise "File not found: #{file_path}" unless File.exist?(file_path)
    end

    def validate_media_category!(media_category:)
      return if MEDIA_CATEGORIES.include?(media_category.downcase)

      raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
    end
  end
end
