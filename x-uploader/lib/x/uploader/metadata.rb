require "x/core"

module X
  module Uploader
    # Describes uploaded media with alt text, and uploaded videos with subtitles
    # @api public
    module Metadata
      extend self

      # The media category the subtitles endpoint takes for a video attached to a post
      SUBTITLED_MEDIA_CATEGORY = "TweetVideo".freeze
      # The media category the subtitles endpoint takes for a video uploaded as amplify_video
      AMPLIFY_SUBTITLED_MEDIA_CATEGORY = "AmplifyVideo".freeze

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # @api public
      # @param media [Hash, String, Integer] the upload response, or the media identifier
      # @param text [String] the alt text, up to 1,000 characters
      # @param client [Client] the X API client
      # @return [Hash, nil] the media identifier and the metadata now associated with it
      # @example Describe an uploaded image
      #   Uploader::Metadata.add_alt_text(media, "A cat asleep on a keyboard", client: client)
      def add_alt_text(media, text, client:)
        client.post("media/metadata", {id: media_id(media), metadata: {alt_text: {text:}}})&.fetch("data")
      end

      # Attach uploaded subtitles to an uploaded video
      #
      # @api public
      # @param video [Hash, String, Integer] the upload response of the video, or its media identifier
      # @param subtitles [Hash, String, Integer] the upload response of the .srt file, or its media identifier
      # @param language_code [String] the two-letter language code of the subtitles, such as EN
      # @param client [Client] the X API client
      # @param display_name [String, nil] the name of the language shown to viewers, such as English
      # @param media_category [String] TweetVideo, or AmplifyVideo for a video uploaded as amplify_video
      # @return [Hash, nil] the video identifier and the subtitles now associated with it
      # @example Upload a video and its English subtitles
      #   video = Uploader::Media.upload("cat.mp4", client: client)
      #   subtitles = Uploader::Media.upload("cat.srt", client: client)
      #   Uploader::Metadata.add_subtitles(video, subtitles, "EN", client: client, display_name: "English")
      # @example Subtitle an Amplify video
      #   video = Uploader::Media.upload("cat.mp4", client: client, media_category: "amplify_video")
      #   Uploader::Metadata.add_subtitles(video, subtitles, "EN", client: client, media_category: "AmplifyVideo")
      def add_subtitles(video, subtitles, language_code, client:, display_name: nil, media_category: SUBTITLED_MEDIA_CATEGORY)
        track = {id: media_id(subtitles), language_code: language_code.upcase, display_name:}.compact
        client.post("media/subtitles", {id: media_id(video), media_category:, subtitles: track})&.fetch("data")
      end

      private

      # The media identifier of an upload response or of an identifier
      # @api private
      # @param media [Hash, String, Integer] the upload response, or the media identifier
      # @return [String] the media identifier
      def media_id(media) = media.is_a?(Hash) ? media.fetch("id").to_s : media.to_s
    end
  end
end
