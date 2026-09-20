require_relative "uploaded_media"

module X
  module Uploader
    # Helpers shared across the uploaders
    #
    # Internal to x-uploader: the uploaders call it rather than mix its methods into themselves, so a class that
    # includes an uploader gains none of them.
    #
    # @api private
    module Utils
      extend self

      # The media categories the subtitles endpoint takes, by the category the video was uploaded as
      SUBTITLED_MEDIA_CATEGORIES = {"tweet_video" => "TweetVideo", "amplify_video" => "AmplifyVideo"}.freeze

      # The lowercase extension of a file, without its dot
      #
      # @api private
      # @param file_path [String, Pathname] the path to the file
      # @return [String] the extension
      # @example The extension of a file
      #   Uploader::Utils.extension("cat.JPG") # => "jpg"
      def extension(file_path) = File.extname(file_path).delete(".").downcase

      # The media identifier of an upload response or of an identifier
      #
      # @api private
      # @param media [Hash, String, Integer] the upload response, or the media identifier
      # @return [String] the media identifier
      # @raise [KeyError] if an upload response has no id
      # @example The identifier of uploaded media
      #   Uploader::Utils.media_id({"id" => "1880028106020515840"}) # => "1880028106020515840"
      def media_id(media)
        case media
        when Hash, UploadedMedia then media.fetch("id").to_s
        else media.to_s
        end
      end

      # The media category the subtitles endpoint takes, from one given in any form
      #
      # The uploaders take a category as tweet_video, in any case, and the endpoint names it TweetVideo, so both are
      # taken, and any other category raises before a request the endpoint would refuse.
      #
      # @api private
      # @param media_category [String, Symbol] the media category, in any form
      # @return [String] the media category as the subtitles endpoint names it
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video
      # @example The category of subtitles for a video attached to a post
      #   Uploader::Utils.subtitled_media_category(:tweet_video) # => "TweetVideo"
      def subtitled_media_category(media_category)
        key = media_category.to_s.sub(/([a-z])([A-Z])/, '\1_\2').downcase
        SUBTITLED_MEDIA_CATEGORIES.fetch(key) do
          raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{SUBTITLED_MEDIA_CATEGORIES.keys.join(", ")}"
        end
      end
    end
    private_constant :Utils
  end
end
