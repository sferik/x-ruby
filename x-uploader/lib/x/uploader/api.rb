require_relative "account"
require_relative "media"
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
      # Upload a file and wait for it to be processed
      #
      # A video or subtitles upload in chunks, and the media category is inferred from the file.
      #
      # @api public
      # @param file_path [String, Pathname] the path to the file to upload
      # @param options [Hash] the options of {Media.upload}, such as media_category, alt_text, and processing_timeout
      # @return [UploadedMedia, nil] the uploaded media, which holds the upload response, or the processing status of
      #   media that X processes
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Upload an image with alt text and post it
      #   media = client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
      #   client.create_post("Look at this cat", media_ids: [media])
      def upload_media(file_path, **options)
        Media.upload(file_path, client: self, **options)
      end

      # Upload the content of media that is held in memory, in one request
      #
      # @api public
      # @param content [String] the binary content to upload
      # @param media_category [String] the media category
      # @return [UploadedMedia, nil] the uploaded media, which holds the upload response
      # @raise [ArgumentError] if the media category is invalid
      # @example Upload an image held in memory
      #   client.upload_media_binary(File.binread("cat.png"), media_category: "tweet_image")
      def upload_media_binary(content, media_category:)
        Media.upload_binary(content, client: self, media_category:)
      end

      # Wait until media has been processed, whether its processing succeeded or failed
      #
      # It returns the status X reported, which failed? tells a failure by; await_media_processing! raises for one
      # instead.
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param options [Hash] the options of {Media.await_processing}, such as processing_timeout
      # @return [UploadedMedia, nil] the uploaded media, which holds the processing status, failed or not
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload
      #   video = client.await_media_processing(video)
      #   warn video.processing_info.dig("error", "message") if video.failed?
      def await_media_processing(media, **options)
        Media.await_processing(media, client: self, **options)
      end

      # Wait until media has been processed, raising if its processing failed
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param options [Hash] the options of {Media.await_processing!}, such as processing_timeout
      # @return [UploadedMedia, nil] the uploaded media, which holds the processing status
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload, raising if X could not process it
      #   client.await_media_processing!(video)
      def await_media_processing!(media, **options)
        Media.await_processing!(media, client: self, **options)
      end

      # Describe uploaded media with alt text, for people who cannot see it
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param text [String] the alt text, up to 1,000 characters
      # @return [Hash, nil] the media identifier and the metadata now associated with it
      # @example Describe an image
      #   client.add_alt_text(media, "A cat asleep on a keyboard")
      def add_alt_text(media, text)
        Metadata.add_alt_text(media, text, client: self)
      end

      # Attach uploaded subtitles to an uploaded video
      #
      # @api public
      # @param video [UploadedMedia, Hash, String, Integer] the uploaded video, or its media identifier
      # @param subtitles [UploadedMedia, Hash, String, Integer] the uploaded subtitles, or their media identifier
      # @param language_code [String] the language of the subtitles, such as EN
      # @param options [Hash] the options of {Metadata.add_subtitles}: display_name and media_category
      # @return [Hash, nil] the response data
      # @example Subtitle a video in English
      #   client.add_subtitles(video, subtitles, "EN", display_name: "English")
      def add_subtitles(video, subtitles, language_code, **options)
        Metadata.add_subtitles(video, subtitles, language_code, client: self, **options)
      end

      # Update the profile image of the authenticated user from a file
      #
      # @api public
      # @param file_path [String, Pathname] the path to the image file
      # @return [Hash, nil] the user whose profile image was updated
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the file is not a GIF, JPEG, or PNG image
      # @example Update the profile image
      #   client.update_profile_image("avatar.png")
      def update_profile_image(file_path)
        Account.update_profile_image(file_path, client: self)
      end

      # Update the profile banner of the authenticated user from a file
      #
      # @api public
      # @param file_path [String, Pathname] the path to the image file
      # @param options [Hash] the options of {Account.update_profile_banner}: width, height, offset_left, and offset_top
      # @return [Hash, nil] nil once the banner is updated, which the API answers without content
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [InvalidMediaType] if the file is not a GIF, JPEG, or PNG image
      # @example Update the profile banner
      #   client.update_profile_banner("banner.png", width: 1500, height: 500)
      def update_profile_banner(file_path, **options)
        Account.update_profile_banner(file_path, client: self, **options)
      end
    end
  end
end
