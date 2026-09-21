# frozen_string_literal: true

require "x/core"
require_relative "json_classes"
require_relative "missing_data"
require_relative "utils"

module X
  module Uploader
    # Describes uploaded media with alt text, and uploaded videos with subtitles
    # @api public
    module Metadata
      extend self

      # The media category the subtitles endpoint takes for a video attached to a post
      SUBTITLED_MEDIA_CATEGORY = "TweetVideo"
      # The media category the subtitles endpoint takes for a video uploaded as amplify_video
      AMPLIFY_SUBTITLED_MEDIA_CATEGORY = "AmplifyVideo"
      # The message of the error raised for a metadata response that holds no metadata
      NO_METADATA = "The response that adds the metadata holds none"
      private_constant :NO_METADATA

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param text [String] the alt text, up to 1,000 characters
      # @param client [Client] the X API client
      # @return [Hash, nil] the media identifier and the metadata now associated with it, or nil for a response
      #   that carries no body at all
      # @raise [MissingData] if the media given holds no identifier, or the response holds no metadata
      # @example Describe an uploaded image
      #   Uploader::Metadata.add_alt_text(media, "A cat asleep on a keyboard", client: client)
      def add_alt_text(media, text, client:)
        body = {id: Utils.media_id(media), metadata: {alt_text: {text:}}}
        client.post("media/metadata", body, **JSON_CLASSES)&.fetch("data") { raise MissingData, NO_METADATA }
      end

      # Attach uploaded subtitles to an uploaded video
      #
      # @api public
      # @param video [UploadedMedia, Hash, String, Integer] the uploaded video, or its media identifier
      # @param subtitles [UploadedMedia, Hash, String, Integer] the uploaded .srt file, or its media identifier
      # @param language_code [String] the two-letter language code of the subtitles, such as EN
      # @param client [Client] the X API client
      # @param display_name [String, nil] the name of the language shown to viewers, such as English
      # @param media_category [String, Symbol] the category the video was uploaded as, tweet_video or amplify_video,
      #   in any case, as the uploaders take it, or as the subtitles endpoint names it, TweetVideo or AmplifyVideo
      # @return [Hash, nil] the video identifier and the subtitles now associated with it, or nil for a response
      #   that carries no body at all
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video
      # @raise [MissingData] if the video or the subtitles hold no identifier, or the response holds no metadata
      # @example Upload a video and its English subtitles
      #   video = Uploader::Media.upload("cat.mp4", client: client)
      #   subtitles = Uploader::Media.upload("cat.srt", client: client)
      #   Uploader::Metadata.add_subtitles(video, subtitles, "EN", client: client, display_name: "English")
      # @example Subtitle an Amplify video
      #   video = Uploader::Media.upload("cat.mp4", client: client, media_category: :amplify_video)
      #   Uploader::Metadata.add_subtitles(video, subtitles, "EN", client: client, media_category: :amplify_video)
      def add_subtitles(video, subtitles, language_code, client:, display_name: nil, media_category: SUBTITLED_MEDIA_CATEGORY)
        track = {id: Utils.media_id(subtitles), language_code: language_code.upcase, display_name:}.compact
        body = {id: Utils.media_id(video), media_category: Utils.subtitled_media_category(media_category), subtitles: track}
        client.post("media/subtitles", body, **JSON_CLASSES)&.fetch("data") { raise MissingData, NO_METADATA }
      end
    end
  end
end
