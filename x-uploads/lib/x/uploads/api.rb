# frozen_string_literal: true

require_relative "account"
require_relative "media_upload"
require_relative "metadata"
require_relative "utils"

module X
  module Uploads
    # The upload methods mixed into a client, each of which calls an uploader with the client
    #
    # The x gem includes it into X::Client. With x-core and x-uploads alone, include it yourself:
    # X::Client.include(X::Uploads::API). Each method passes the object it is included into to an uploader as its
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
      # A video or subtitles upload in chunks, which send their media type, as a single request does not. The media
      # category is inferred from the bytes the media begins with, or else from the name of its file, unless
      # media_category says what it is. The chunks are sent by threads of their own, so the on_response of the client
      # runs on those threads for the response of each chunk.
      #
      # An image, and a GIF that a single request takes, upload in a single request, which takes no chunks and no
      # media type, so chunk_size, concurrency, and media_type are ignored for them: a chunk_size or a concurrency
      # that is not valid still raises, but none is sent. Media given shared: true uploads in chunks, and uses all
      # three.
      #
      # Each chunk is a request a rate limit can refuse, which fails the upload with ChunkedUploadFailed unless the
      # client retries it, which it does only max_rate_limit_retries times, 0 by default, so upload a large video with
      # a client whose max_rate_limit_retries is set, such as X::Client.new(max_rate_limit_retries: 3).
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param options [Hash] the options of {MediaUpload.upload}
      # @option options [String, Symbol, nil] :media_category (nil) the media category, in any case, inferred when nil
      #   from the bytes the media begins with, or else from the name of its file
      # @option options [String, nil] :alt_text (nil) alt text describing the media, of 1 to 1,000 characters, added
      #   once the media is uploaded and processed, or nil for none
      # @option options [Integer, Float, nil] :processing_timeout (600) the seconds to wait for media that X processes,
      #   such as a video, to process, of at least 0, or nil to wait for as long as processing takes
      # @option options [String, nil] :media_type (nil) the MIME type of media uploaded in chunks, inferred from the
      #   media and category when nil; ignored for media uploaded in a single request, such as an image
      # @option options [Integer, nil] :chunk_size (nil) the size of each chunk in bytes, of at most 5,242,880, or nil
      #   for MediaUpload::DEFAULT_CHUNK_SIZE, or as much more as the media needs; ignored for media uploaded in a
      #   single request, such as an image
      # @option options [Integer] :concurrency (4) the number of chunks uploaded at once, of 1 to
      #   MediaUpload::MAX_CONCURRENCY; ignored for media uploaded in a single request, such as an image
      # @option options [Boolean, nil] :shared (nil) whether the media can be sent in more than one direct message, or
      #   nil to leave it to the API; media that is shared uploads in chunks
      # @option options [Array<Integer, String>, nil] :additional_owners (nil) the identifiers of the users, other than
      #   the one who uploads it, who may use the media, or nil for none
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
      #   segments than the API numbers, the concurrency is not 1 to MAX_CONCURRENCY, the processing timeout is
      #   neither nil nor a finite number of seconds of at least 0, shared is neither true, false, nor nil, or
      #   additional_owners is neither nil nor an Array of at least one user identifier
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for a request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value: the request
      #   that initializes an upload in chunks, or the single request of any other, raises it as it is, and a later
      #   request that opens a connection fails with it as the cause of the ChunkedUploadFailed,
      #   MediaProcessingCheckFailed, or AltTextFailed it raises
      # @raise [InvalidMediaType] if no media category is given for media whose type neither its bytes nor the name of
      #   its file names, or the category does not take the type of the media
      # @raise [MissingMediaData] if a response of the upload holds no media, or carries no body at all
      # @raise [ChunkedUploadFailed] if media uploaded in chunks is initialized, but a chunk cannot be appended, or it
      #   cannot be finalized, with the media it initialized
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @raise [MediaProcessingCheckFailed] if the media is uploaded, but a check of its processing fails, as when the
      #   API answers it with an error, with the media it uploaded
      # @raise [AltTextFailed] if the media is uploaded, but its alt text cannot be added, with the media it uploaded
      # @raise [TokenReportFailed] if save_tokens raises for the tokens of a refresh a request of the upload made, with
      #   the tokens, rather than the media, whatever the upload had done by then
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

      # Upload media in chunks, without waiting for it to be processed
      #
      # It is the way to upload media without waiting for X to process it: {#upload_media} waits for the processing of
      # media X processes, such as a video, and this does not. It uploads the media as {#upload_media} uploads a video,
      # a chunk at a time, but returns once the upload is finalized, so that the caller can go on while X processes a
      # long video, and wait for it with {#await_media_processing} or {#await_media_processing!} when it needs it. It
      # uploads in chunks whatever the media, an image as well, and adds no alt text. The
      # chunks are sent by threads of their own, so the on_response of the client runs on those threads for the
      # response of each chunk.
      #
      # Each chunk is a request a rate limit can refuse, which fails the upload with ChunkedUploadFailed unless the
      # client retries it, which it does only max_rate_limit_retries times, 0 by default, so upload a large video with
      # a client whose max_rate_limit_retries is set, such as X::Client.new(max_rate_limit_retries: 3).
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param options [Hash] the options of {MediaUpload.chunked_upload}
      # @option options [String, Symbol, nil] :media_category (nil) the media category, in any case, inferred when nil
      #   from the bytes the media begins with, or else from the name of its file
      # @option options [String, nil] :media_type (nil) the MIME type of the media, sent as it is given, or inferred
      #   from the media and category when nil
      # @option options [Integer, nil] :chunk_size (nil) the size of each chunk in bytes, of at most 5,242,880, or nil
      #   for MediaUpload::DEFAULT_CHUNK_SIZE, or as much more as the media needs
      # @option options [Integer] :concurrency (4) the number of chunks uploaded at once, of 1 to
      #   MediaUpload::MAX_CONCURRENCY
      # @option options [Boolean, nil] :shared (nil) whether the media can be sent in more than one direct message, or
      #   nil to leave it to the API
      # @option options [Array<Integer, String>, nil] :additional_owners (nil) the identifiers of the users, other than
      #   the one who uploads it, who may use the media, or nil for none
      # @return [UploadedMedia] the uploaded media, which holds the response that finalized the upload, and the
      #   processing status of media that X processes
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds a NUL byte or a
      #   line break, as the contents of media given in place of its path do
      # @raise [InvalidMedia] if the file does not exist, the media cannot be read, or is empty, or it is larger than
      #   the API takes of its category
      # @raise [ArgumentError] if the media category is invalid, the chunk size is not a positive Integer, is larger
      #   than a segment the API takes, or would need more segments than the API numbers, the concurrency is not 1 to
      #   MAX_CONCURRENCY, shared is neither true, false, nor nil, or additional_owners is neither nil nor an Array of
      #   at least one user identifier
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for a request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value: the request
      #   that initializes the upload raises it as it is, and a chunk or the finalize that opens a connection fails
      #   with it as the cause of the ChunkedUploadFailed it raises
      # @raise [InvalidMediaType] if no media type is given and none can be inferred, or the one the media is, read
      #   from its bytes or else from the name of its file, is not one the category takes
      # @raise [MissingMediaData] if the response that initializes the upload holds no media to append the chunks to
      # @raise [ChunkedUploadFailed] if the upload is initialized, but a chunk cannot be appended, or it cannot be
      #   finalized, with the media it initialized
      # @raise [TokenReportFailed] if save_tokens raises for the tokens of a refresh a request of the upload made, with
      #   the tokens, rather than the media, whatever the upload had done by then
      # @example Upload a long video, and wait for X to process it once it is needed
      #   video = client.chunked_upload_media("talk.mp4", concurrency: 8)
      #   client.create_post("Watch the talk", media_ids: [client.await_media_processing!(video)])
      def chunked_upload_media(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.chunked_upload(media, client: _ = self, **Utils.without_client(options))
      end

      # Wait until media has been processed, whether its processing succeeded or failed
      #
      # It returns the status X reported, which failed? tells a failure by, and ready? a success by;
      # await_media_processing! raises for a failure instead. It waits through any other state, one X does not
      # document among them, as it waits while processing is pending or in progress. Media that already says its
      # processing succeeded or failed, or holds an upload response that names no processing, such as that of an
      # image, is returned as it is, without a request.
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param options [Hash] the options of {MediaUpload.await_processing}
      # @option options [Integer, Float, nil] :processing_timeout (600) the seconds from now to wait for processing to
      #   finish, checks and all, of at least 0, or nil to wait for as long as processing takes
      # @return [UploadedMedia] the uploaded media, which holds the processing status, failed or not, or the media
      #   given, as uploaded media, if its processing has already ended
      # @raise [ArgumentError] if the processing timeout is neither nil nor a finite number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload_media
      #   video = client.await_media_processing(video)
      #   warn "#{video.id} failed to process" if video.failed?
      def await_media_processing(media, **options) # steep:ignore DifferentMethodParameterKind
        MediaUpload.await_processing(media, client: _ = self, **Utils.without_client(options))
      end

      # Wait until media has been processed, raising if its processing failed
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param options [Hash] the options of {MediaUpload.await_processing!}
      # @option options [Integer, Float, nil] :processing_timeout (600) the seconds from now to wait for processing to
      #   finish, checks and all, of at least 0, or nil to wait for as long as processing takes
      # @return [UploadedMedia] the uploaded media, which holds the processing status, or the media given, as uploaded
      #   media, if its processing has already succeeded
      # @raise [ArgumentError] if the processing timeout is neither nil nor a finite number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported, or the media given,
      #   without a request, if it already says its processing failed
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for a video uploaded with chunked_upload_media, raising if X could not process it
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
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
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
      # @param options [Hash] the options of {Metadata.add_subtitles}
      # @option options [String, nil] :display_name (nil) the name of the language shown to viewers, such as English,
      #   or nil for none
      # @option options [String, Symbol] :media_category ("tweet_video") the category the video was uploaded as,
      #   tweet_video or amplify_video, in any case, or TweetVideo or AmplifyVideo, as the subtitles endpoint names them
      # @return [UploadedMedia] the video given, as uploaded media, which a call can be chained to
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video, or the language code is
      #   not two letters
      # @raise [ArgumentError] if the video or the subtitles are nil, hold no identifier, are neither media, a media
      #   key, nor a media identifier, have a media key that names none, or an identifier the API does not take
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
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
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
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
      # @param options [Hash] the options of {Account.update_profile_banner}, which give the region of the image to use
      # @option options [Integer, nil] :width (nil) the width of the region, in pixels, of at least 1
      # @option options [Integer, nil] :height (nil) the height of the region, in pixels, of at least 1
      # @option options [Integer, nil] :offset_left (nil) the pixels by which the region is offset from the left, of at
      #   least 0
      # @option options [Integer, nil] :offset_top (nil) the pixels by which the region is offset from the top, of at
      #   least 0
      # @return [void]
      # @raise [InvalidMedia] if the file does not exist
      # @raise [ArgumentError] if the media is neither a path nor an IO, or a width, height, or offset is neither nil
      #   nor an Integer of the pixels it takes
      # @raise [ArgumentError] if the client was given no proxy_url and the proxy the environment names for the request
      #   cannot be parsed, or is not an http or https URL with a host, with a message that names the variables read and
      #   leaves out the value
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
