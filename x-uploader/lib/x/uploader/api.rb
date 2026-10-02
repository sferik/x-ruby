# frozen_string_literal: true

require_relative "account"
require_relative "media_upload"
require_relative "metadata"
require_relative "utils"

module X
  module Uploader
    # The upload methods mixed into a client, each of which calls an uploader with the client
    #
    # The x gem includes it into X::Client. With x-core and x-uploader alone, include it yourself:
    # X::Client.include(X::Uploader::API). Each method passes the object it is included into to an uploader as its
    # client, which is an X::Client, so it belongs in X::Client or a subclass.
    #
    # @api public
    module API
      # Upload media and wait for it to be processed
      #
      # The media is a path, or an IO open on it. Media given as a String or a Pathname is read from the file it names,
      # and media given as a File or a Tempfile through that IO, a chunk at a time, so media of any size uploads
      # without being held in memory; media given as any other IO, such as a StringIO, is read to its end and held.
      #
      # A video or subtitles upload in chunks. The media category is inferred from the bytes the media begins with, or
      # else from the name of its file, unless media_category says what it is. The chunks are sent by threads of their
      # own, so the on_response of the client runs on those threads for the response of each chunk.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param options [Hash] the options of {MediaUpload.upload}, such as media_category, alt_text, processing_timeout,
      #   shared, and additional_owners
      # @return [UploadedMedia] the uploaded media, which holds the upload response, or the processing status of
      #   media that X processes
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds a NUL byte or a
      #   line break, as the contents of media given in place of its path do
      # @raise [InvalidMedia] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMedia] if the media is larger than the API takes of its category, whatever the account: 5
      #   megabytes of an image, 15 of a GIF, and one of subtitles, or larger than the 16 gigabytes it takes of any
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or longer than the API takes,
      #   the chunk size is not a positive Integer, is larger than a segment the API takes, or would need more
      #   segments than the API numbers, the concurrency is not 1 to MAX_CONCURRENCY, the processing timeout is not a
      #   number of seconds of at least 0, shared is neither true, false, nor nil, or additional_owners is neither nil
      #   nor an Array of at least one user identifier
      # @raise [InvalidMediaType] if no media category is given for media whose type neither its bytes nor the name of
      #   its file names, or the category does not take the type of the media
      # @raise [MissingMediaData] if a response of the upload holds no media, or carries no body at all
      # @raise [ChunkedUploadFailed] if media uploaded in chunks is initialized, but a chunk cannot be appended, or it
      #   cannot be finalized, with the media it initialized
      # @raise [MediaProcessingFailed] if media processing failed, or ended in no state X documents, with the status X
      #   reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @raise [MediaProcessingCheckFailed] if the media is uploaded, but a check of its processing fails, as when the
      #   API answers it with an error, with the media it uploaded
      # @raise [AltTextFailed] if the media is uploaded, but its alt text cannot be added, with the media it uploaded
      # @example Upload an image with alt text and post it
      #   media = client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
      #   client.create_post("Look at this cat", media_ids: [media])
      # @example Upload an image held in memory, whose category its signature names
      #   client.upload_media(StringIO.new(File.binread("cat.png")))
      # @example Upload media of a category no signature names
      #   client.upload_media(StringIO.new(subtitles), media_category: "subtitles")
      def upload_media(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.upload(media, client: _ = self, **Utils.without_client(options))
      end

      # Wait until media has been processed, whether its processing succeeded or failed
      #
      # It returns the status X reported, which failed? tells a failure by, and ready? a success by, since a status
      # in no state X documents is neither; await_media_processing! raises for either instead.
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param options [Hash] the options of {MediaUpload.await_processing}, such as processing_timeout
      # @return [UploadedMedia] the uploaded media, which holds the processing status, failed or not
      # @raise [ArgumentError] if the processing timeout is not a number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with MediaUpload.chunked_upload
      #   video = client.await_media_processing(video)
      #   warn video.processing_info.dig("error", "message") if video.failed?
      def await_media_processing(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.await_processing(media, client: _ = self, **Utils.without_client(options))
      end

      # Wait until media has been processed, raising if its processing failed
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param options [Hash] the options of {MediaUpload.await_processing!}, such as processing_timeout
      # @return [UploadedMedia] the uploaded media, which holds the processing status
      # @raise [ArgumentError] if the processing timeout is not a number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingFailed] if media processing failed, or ended in no state X documents, with the status X
      #   reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with MediaUpload.chunked_upload, raising if X could not process it
      #   client.await_media_processing!(video)
      def await_media_processing!(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.await_processing!(media, client: _ = self, **Utils.without_client(options))
      end

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param text [String] the alt text, of 1 to 1,000 characters
      # @return [UploadedMedia] the media given, as uploaded media, which a call can be chained to
      # @raise [ArgumentError] if the alt text is empty or longer than the API takes, before a request
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [MissingMediaData] if the response holds no metadata or carries no body at all
      # @example Describe an image
      #   client.add_alt_text(media, "A cat asleep on a keyboard")
      # @example Describe an image as it is uploaded
      #   media = client.add_alt_text(client.upload_media("cat.jpg"), "A cat asleep on a keyboard")
      def add_alt_text(media, text)
        Metadata.add_alt_text(media, text, client: _ = self)
      end

      # Attach uploaded subtitles to an uploaded video
      #
      # @api public
      # @param video [UploadedMedia, Hash, #media_key, String, Integer] the uploaded video, media that has a media
      #   key, such as X::Media, or its media identifier
      # @param subtitles [UploadedMedia, Hash, #media_key, String, Integer] the uploaded subtitles, media that has a
      #   media key, or their media identifier
      # @param language_code [String] the language of the subtitles, such as EN
      # @param options [Hash] the options of {Metadata.add_subtitles}: display_name and media_category
      # @return [UploadedMedia] the video given, as uploaded media, which a call can be chained to
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video, or the language code is
      #   not two letters
      # @raise [ArgumentError] if the video or the subtitles are nil, hold no identifier, are neither media, a media
      #   key, nor a media identifier, have a media key that names none, or an identifier the API does not take
      # @raise [MissingMediaData] if the response holds no metadata or carries no body at all
      # @example Subtitle a video in English
      #   client.add_subtitles(video, subtitles, "EN", display_name: "English")
      def add_subtitles(video, subtitles, language_code, **options) # steep:ignore DifferentMethodParameterKind
        Metadata.add_subtitles(video, subtitles, language_code, client: _ = self, **Utils.without_client(options))
      end

      # Update the profile image of the authenticated user from a file
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it
      # @return [void]
      # @raise [InvalidMedia] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @raise [InvalidMedia] if the media cannot be read, is empty, or is larger than the 700 kilobytes the API takes
      # @raise [InvalidMediaType] if the image does not begin with the signature of a GIF, a JPEG, or a PNG
      # @example Update the profile image
      #   client.update_profile_image("avatar.png")
      def update_profile_image(media)
        Account.update_profile_image(media, client: _ = self)
      end

      # Update the profile banner of the authenticated user from a file
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it
      # @param options [Hash] the options of {Account.update_profile_banner}: width, height, offset_left, and offset_top
      # @return [void]
      # @raise [InvalidMedia] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO, or a width, height, or offset is neither nil
      #   nor an Integer of the pixels it takes
      # @raise [InvalidMedia] if the media cannot be read, is empty, or is larger than the 5 megabytes X takes
      # @raise [InvalidMediaType] if the image does not begin with the signature of a GIF, a JPEG, or a PNG
      # @example Update the profile banner
      #   client.update_profile_banner("banner.png", width: 1500, height: 500)
      def update_profile_banner(media, **options) # steep:ignore DifferentMethodParameterKind
        Account.update_profile_banner(media, client: _ = self, **Utils.without_client(options))
      end
    end
  end
end
