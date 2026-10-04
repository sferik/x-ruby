# frozen_string_literal: true

require "x/core"
require_relative "json_classes"
require_relative "missing_media_data"
require_relative "utils"
require_relative "validator"

module X
  module Uploads
    # Describes uploaded media with alt text, and uploaded videos with subtitles
    # @api public
    module Metadata
      extend self

      # The media category of a video attached to a post, which subtitles default to, named as the uploaders name it
      SUBTITLED_MEDIA_CATEGORY = "tweet_video"
      private_constant :SUBTITLED_MEDIA_CATEGORY

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # Alt text added twice is added once, so it is sent again after a server or network error, up to the
      # max_retries of the client, even after a timeout, which a client sends no read again after: X bills a metadata
      # request each time it is sent, so one whose answer was lost may be billed twice.
      #
      # It returns the media it described, as uploaded media, so that a call can be chained to the upload it
      # describes. The response holds nothing more than the media identifier and the alt text that was sent.
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param text [String] the alt text, of 1 to 1,000 characters
      # @param client [Client] the X API client
      # @return [UploadedMedia] the media given, if it is uploaded media, or else uploaded media built from the upload
      #   response, the media key, or the media identifier given
      # @raise [ArgumentError] if the alt text is empty or longer than the API takes, before a request
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
      # @raise [MissingMediaData] if the response holds no metadata or carries no body at all
      # @example Describe an uploaded image
      #   Uploads::Metadata.add_alt_text(media, "A cat asleep on a keyboard", client: client)
      # @example Describe an image as it is uploaded, and attach it to a post
      #   media = Uploads::Metadata.add_alt_text(Uploads::MediaUpload.upload("cat.jpg", client:), "A cat", client:)
      #   client.post("tweets", {text: "Look at this cat", media: {media_ids: [media.media_id.to_s]}})
      def add_alt_text(media, text, client:)
        Validator.validate_alt_text!(text)
        body = {id: Utils.media_id(media), metadata: {alt_text: {text:}}}
        Utils.described(Utils.sending_again(client) { client.post("media/metadata", body, **JSON_CLASSES) }, media)
      end

      # Attach uploaded subtitles to an uploaded video
      #
      # Subtitles attached twice are attached once, as the track of their language, so they are sent again after a
      # server or network error, as alt text is, up to the max_retries of the client.
      #
      # It returns the video it subtitled, as uploaded media, so that a call can be chained to the upload of the
      # video. The response holds nothing more than the identifiers, the category, and the track that were sent.
      #
      # @api public
      # @param video [UploadedMedia, Hash, #media_key, String, Integer] the uploaded video, media that has a media
      #   key, such as X::Media, or its media identifier
      # @param subtitles [UploadedMedia, Hash, #media_key, String, Integer] the uploaded .srt or .vtt file, media
      #   that has a media key, or its media identifier
      # @param language_code [String] the two-letter language code of the subtitles, in any case, such as EN
      # @param client [Client] the X API client
      # @param display_name [String, nil] the name of the language shown to viewers, such as English
      # @param media_category [String, Symbol] the category the video was uploaded as, tweet_video, the default, or
      #   amplify_video, in any case, as the uploaders take it, or as the subtitles endpoint names it, TweetVideo or
      #   AmplifyVideo
      # @return [UploadedMedia] the video given, if it is uploaded media, or else uploaded media built from the upload
      #   response, the media key, or the media identifier given
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video, or the language code is
      #   not two letters
      # @raise [ArgumentError] if the video or the subtitles are nil, hold no identifier, are neither media, a media
      #   key, nor a media identifier, have a media key that names none, or an identifier the API does not take
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
      # @raise [MissingMediaData] if the response holds no metadata or carries no body at all
      # @example Upload a video and its English subtitles
      #   video = Uploads::MediaUpload.upload("cat.mp4", client: client)
      #   subtitles = Uploads::MediaUpload.upload("cat.srt", client: client)
      #   Uploads::Metadata.add_subtitles(video, subtitles, "EN", client: client, display_name: "English")
      # @example Subtitle an Amplify video
      #   video = Uploads::MediaUpload.upload("cat.mp4", client: client, media_category: :amplify_video)
      #   Uploads::Metadata.add_subtitles(video, subtitles, "EN", client: client, media_category: :amplify_video)
      def add_subtitles(video, subtitles, language_code, client:, display_name: nil, media_category: SUBTITLED_MEDIA_CATEGORY)
        track = {id: Utils.media_id(subtitles), language_code: Validator.validate_language_code!(language_code), display_name:}.compact
        body = {id: Utils.media_id(video), media_category: Utils.subtitled_media_category(media_category), subtitles: track}
        Utils.described(Utils.sending_again(client) { client.post("media/subtitles", body, **JSON_CLASSES) }, video)
      end
    end
  end
end
