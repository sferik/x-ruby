# frozen_string_literal: true

require_relative "account"
require_relative "media_upload"
require_relative "metadata"

module X
  module Uploader
    # The upload methods mixed into a client, each of which calls an uploader with the client
    #
    # The x gem includes it into X::Client. With x-core and x-uploader alone, include it yourself:
    # X::Client.include(X::Uploader::API).
    #
    # @api public
    module API
      # Upload media and wait for it to be processed
      #
      # The media is a path, or an IO open on it. Media given as a String or a Pathname is read from the file it names,
      # and media given as a File or a Tempfile through that IO, a chunk at a time, so media of any size uploads
      # without being held in memory; media given as any other IO, such as a StringIO, is read to its end and held.
      #
      # A video or subtitles upload in chunks. The media category is inferred from the name of the file, or, for
      # media that names none, from the bytes it begins with, unless media_category says what it is.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param options [Hash] the options of {MediaUpload.upload}, such as media_category, alt_text, and processing_timeout
      # @return [UploadedMedia] the uploaded media, which holds the upload response, or the processing status of
      #   media that X processes
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds a NUL byte or a
      #   line break, as the contents of media given in place of its path do
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMedia] if the media is larger than the API takes of its category, whatever the account: 5
      #   megabytes of an image, 15 of a GIF, and one of subtitles, or larger than the 16 gigabytes it takes of any
      # @raise [InvalidMediaType] if no media category is given for media that names no file and no signature names one
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
        MediaUpload.upload(media, client: self, **without_client(options))
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
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload
      #   video = client.await_media_processing(video)
      #   warn video.processing_info.dig("error", "message") if video.failed?
      def await_media_processing(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.await_processing(media, client: self, **without_client(options))
      end

      # Wait until media has been processed, raising if its processing failed
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param options [Hash] the options of {MediaUpload.await_processing!}, such as processing_timeout
      # @return [UploadedMedia] the uploaded media, which holds the processing status
      # @raise [MediaProcessingFailed] if media processing failed, or ended in no state X documents, with the status X
      #   reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload, raising if X could not process it
      #   client.await_media_processing!(video)
      def await_media_processing!(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.await_processing!(media, client: self, **without_client(options))
      end

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param text [String] the alt text, of 1 to 1,000 characters
      # @return [UploadedMedia] the media given, as uploaded media, which a call can be chained to
      # @raise [ArgumentError] if the alt text is empty or longer than the API takes, before a request
      # @example Describe an image
      #   client.add_alt_text(media, "A cat asleep on a keyboard")
      # @example Describe an image as it is uploaded
      #   media = client.add_alt_text(client.upload_media("cat.jpg"), "A cat asleep on a keyboard")
      def add_alt_text(media, text)
        Metadata.add_alt_text(media, text, client: self)
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
      # @example Subtitle a video in English
      #   client.add_subtitles(video, subtitles, "EN", display_name: "English")
      def add_subtitles(video, subtitles, language_code, **options) # steep:ignore DifferentMethodParameterKind
        Metadata.add_subtitles(video, subtitles, language_code, client: self, **without_client(options))
      end

      # Update the profile image of the authenticated user from a file
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it
      # @return [Hash, nil] the user whose profile image was updated, as the Hash of the API v1.1 that
      #   {Account.update_profile_image} returns, or nil for a response with no body
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the image is not a GIF, JPEG, or PNG image
      # @example Update the profile image
      #   client.update_profile_image("avatar.png")
      def update_profile_image(media)
        Account.update_profile_image(media, client: self)
      end

      # Update the profile banner of the authenticated user from a file
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the image, or an IO that reads it
      # @param options [Hash] the options of {Account.update_profile_banner}: width, height, offset_left, and offset_top
      # @return [nil] nil once the banner is updated, which the API answers with no content
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the image is not a GIF, JPEG, or PNG image
      # @example Update the profile banner
      #   client.update_profile_banner("banner.png", width: 1500, height: 500)
      def update_profile_banner(media, **options) # steep:ignore DifferentMethodParameterKind
        Account.update_profile_banner(media, client: self, **without_client(options))
      end

      private

      # The options of an uploader, which name no client
      #
      # A method of a client uploads with that client, so a client among the options, which would upload with the
      # credentials of another, raises as a keyword the method does not take raises, rather than take its place.
      #
      # @api private
      # @param options [Hash{Symbol => Object}] the options the method was given
      # @return [Hash{Symbol => Object}] the options
      # @raise [ArgumentError] if the options name a client
      def without_client(options)
        raise ArgumentError, "unknown keyword: :client" if options.key?(:client)

        options
      end
    end
  end
end
