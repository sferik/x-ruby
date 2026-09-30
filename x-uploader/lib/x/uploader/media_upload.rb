# frozen_string_literal: true

require "json"
require "securerandom"
require "x/core"
require_relative "alt_text_failed"
require_relative "chunked_upload_failed"
require_relative "media_processing_check_failed"
require_relative "chunks"
require_relative "gif"
require_relative "invalid_media_type"
require_relative "json_classes"
require_relative "media_processing_failed"
require_relative "media_processing_timeout"
require_relative "metadata"
require_relative "multipart"
require_relative "signature"
require_relative "source"
require_relative "uploaded_media"
require_relative "utils"
require_relative "validator"
require_relative "version"

module X
  module Uploader
    # Uploads media files to the X API
    #
    # Its methods can be called on the module, or on an instance of a class that includes it, which gains its public
    # methods alone: what they call besides each other belongs to modules of its own, so no method the class defines
    # under another name can change an upload.
    #
    # @api public
    module MediaUpload
      extend self

      # Number of bytes per megabyte
      BYTES_PER_MB = Validator::BYTES_PER_MB
      # Greatest number of bytes the API takes in a single upload request, above which an animated GIF, which it
      # takes in chunks of up to 15 MB, uploads in chunks
      MAX_SIMPLE_UPLOAD_BYTES = Validator::MAX_SIMPLE_UPLOAD_BYTES
      # Media category constants
      AMPLIFY_VIDEO, DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = Validator::MEDIA_CATEGORIES
      # Supported MIME types: every media type the API documents for an upload of a media category it documents. The
      # initialization of an upload also takes the types of a glTF or USDZ 3D model, model/gltf-binary and
      # model/vnd.usdz+zip, but no media category takes a model, so they are left out, and a file of either raises
      # before a request, rather than be sent as an image X refuses once it is uploaded.
      MIME_TYPES = %w[image/bmp image/gif image/jpeg image/pjpeg image/png image/tiff image/webp text/srt text/vtt
        video/mp2t video/mp4 video/quicktime video/webm].map(&:freeze).freeze
      # MIME type constants
      BMP_MIME_TYPE, GIF_MIME_TYPE, JPEG_MIME_TYPE, PJPEG_MIME_TYPE, PNG_MIME_TYPE, TIFF_MIME_TYPE, WEBP_MIME_TYPE,
        SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE, MPEG_TS_MIME_TYPE, MP4_MIME_TYPE, QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE = MIME_TYPES
      # Mapping of file extensions to MIME types
      MIME_TYPE_MAP = {
        "bmp" => BMP_MIME_TYPE, "gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "pjp" => PJPEG_MIME_TYPE,
        "pjpeg" => PJPEG_MIME_TYPE, "png" => PNG_MIME_TYPE, "tif" => TIFF_MIME_TYPE, "tiff" => TIFF_MIME_TYPE, "webp" => WEBP_MIME_TYPE,
        "srt" => SUBRIP_MIME_TYPE, "vtt" => WEBVTT_MIME_TYPE,
        "m2ts" => MPEG_TS_MIME_TYPE, "mts" => MPEG_TS_MIME_TYPE, "ts" => MPEG_TS_MIME_TYPE, "m4v" => MP4_MIME_TYPE,
        "mp4" => MP4_MIME_TYPE, "mov" => QUICKTIME_MIME_TYPE, "qt" => QUICKTIME_MIME_TYPE, "webm" => WEBM_MIME_TYPE
      }.freeze
      # MIME types of the images the API takes, which an image category takes every one of: a GIF of a single frame is
      # an image, since X processes only animated GIFs as GIFs
      IMAGE_MIME_TYPES = [BMP_MIME_TYPE, GIF_MIME_TYPE, JPEG_MIME_TYPE, PJPEG_MIME_TYPE, PNG_MIME_TYPE, TIFF_MIME_TYPE, WEBP_MIME_TYPE].freeze
      # MIME types of the videos the API takes, the first of which a video of no known type is uploaded as
      VIDEO_MIME_TYPES = [MP4_MIME_TYPE, QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE, MPEG_TS_MIME_TYPE].freeze
      # MIME types of the subtitles the API takes, the first of which subtitles of no known type are uploaded as
      SUBTITLES_MIME_TYPES = [SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE].freeze
      # MIME types every file of which begins with a signature {Signature} reads, so that a file named as one that
      # begins with none is not what its name says, such as TypeScript named .ts, which MPEG-TS is named too. An MP4
      # or QuickTime file may begin with a brand, or an atom, that names no type, and SubRip subtitles with nothing a
      # text file could not, so a file named as one of those is typed by its name.
      SIGNED_MIME_TYPES = [BMP_MIME_TYPE, GIF_MIME_TYPE, JPEG_MIME_TYPE, PJPEG_MIME_TYPE, PNG_MIME_TYPE, TIFF_MIME_TYPE,
        WEBP_MIME_TYPE, WEBVTT_MIME_TYPE, MPEG_TS_MIME_TYPE].freeze
      # Default number of seconds await_processing waits for processing to finish before it gives up
      DEFAULT_PROCESSING_TIMEOUT = 600
      # Default number of chunks uploaded at once
      DEFAULT_CONCURRENCY = 4
      # Greatest number of chunks uploaded at once, each of which holds a chunk of up to 5 megabytes and a connection
      MAX_CONCURRENCY = Validator::MAX_CONCURRENCY
      # The command that asks the upload endpoint how far the processing of media has got
      STATUS_COMMAND = "STATUS"
      # Media categories that are uploaded in chunks and processed after the upload
      VIDEO_CATEGORIES = [AMPLIFY_VIDEO, DM_VIDEO, TWEET_VIDEO].freeze
      # Media categories uploaded in chunks: videos, and subtitles, which the API takes no other way
      CHUNKED_CATEGORIES = [*VIDEO_CATEGORIES, SUBTITLES].freeze
      # Media categories of animated GIFs, which upload in chunks only when a single request cannot take them
      GIF_CATEGORIES = [DM_GIF, TWEET_GIF].freeze
      # Greatest number of bytes the API takes of a GIF, which one is read no further than
      MAX_GIF_BYTES = Validator::MAX_MEDIA_BYTES.fetch(TWEET_GIF)
      # Mapping of MIME types to the media categories of posts; any other type is an image
      TYPE_CATEGORIES = {
        GIF_MIME_TYPE => TWEET_GIF, MPEG_TS_MIME_TYPE => TWEET_VIDEO, MP4_MIME_TYPE => TWEET_VIDEO,
        QUICKTIME_MIME_TYPE => TWEET_VIDEO, WEBM_MIME_TYPE => TWEET_VIDEO, SUBRIP_MIME_TYPE => SUBTITLES,
        WEBVTT_MIME_TYPE => SUBTITLES
      }.freeze
      # The containers of the video file extensions the API documents no media type for, by extension: a video the
      # API takes is MP4, QuickTime, WebM, or MPEG-TS, so a file of one of these uploads only as the type its signature
      # names, such as a WebM video named .mkv, and raises before a request otherwise, rather than be sent as a type
      # it is not
      UNDOCUMENTED_VIDEOS = {"avi" => "AVI", "mkv" => "Matroska"}.freeze
      # The formats of the 3D model file extensions no media category the API documents takes, by extension: the
      # initialization of an upload takes their media types, but X attaches images, GIFs, and videos to a post, so a
      # file of one raises before a request, rather than be sent as an image
      UNDOCUMENTED_MODELS = {"glb" => "glTF", "usdz" => "USDZ"}.freeze
      # Mapping of media categories to the MIME types they take; a video or subtitles category uploads media of no
      # known type as its first, since an MP4 video or SubRip subtitles may begin with no signature that names them
      CATEGORY_MIME_TYPES = {
        TWEET_IMAGE => IMAGE_MIME_TYPES, DM_IMAGE => IMAGE_MIME_TYPES, TWEET_GIF => [GIF_MIME_TYPE], DM_GIF => [GIF_MIME_TYPE],
        TWEET_VIDEO => VIDEO_MIME_TYPES, DM_VIDEO => VIDEO_MIME_TYPES, AMPLIFY_VIDEO => VIDEO_MIME_TYPES,
        SUBTITLES => SUBTITLES_MIME_TYPES
      }.freeze
      private_constant :MIME_TYPES, :BMP_MIME_TYPE, :GIF_MIME_TYPE, :JPEG_MIME_TYPE, :PJPEG_MIME_TYPE, :PNG_MIME_TYPE,
        :TIFF_MIME_TYPE, :WEBP_MIME_TYPE, :SUBRIP_MIME_TYPE, :WEBVTT_MIME_TYPE, :MPEG_TS_MIME_TYPE, :MP4_MIME_TYPE,
        :QUICKTIME_MIME_TYPE, :WEBM_MIME_TYPE, :MIME_TYPE_MAP, :IMAGE_MIME_TYPES, :VIDEO_MIME_TYPES, :SUBTITLES_MIME_TYPES,
        :SIGNED_MIME_TYPES, :STATUS_COMMAND, :VIDEO_CATEGORIES, :CHUNKED_CATEGORIES, :GIF_CATEGORIES, :TYPE_CATEGORIES,
        :CATEGORY_MIME_TYPES, :MAX_GIF_BYTES, :UNDOCUMENTED_VIDEOS, :UNDOCUMENTED_MODELS, :BYTES_PER_MB, :MAX_SIMPLE_UPLOAD_BYTES

      # Upload media, in chunks when the API needs them, awaiting any processing
      #
      # The media is a path, or an IO open on it, which {Source} says how each of is read.
      #
      # A video and subtitles upload in chunks, as does an animated GIF that a single request cannot take. Every
      # argument is validated before the first request, so that no media is uploaded, and billed, for an upload
      # that cannot finish.
      #
      # Media the response of the upload says is still processing is awaited as {await_processing!} awaits it. Media
      # the response says has already failed to process raises MediaProcessingFailed with that response, and media it
      # says has finished is returned as it is, without a check of its status.
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param client [Client] the X API client
      # @param media_category [String, Symbol, nil] the media category, in any case, inferred when nil from the bytes
      #   the media begins with, or else from the name of its file
      # @param alt_text [String, nil] alt text describing the media, for people who cannot see it, of 1 to 1,000 characters
      # @param processing_timeout [Integer, Float] the seconds to wait for media, such as a video or an animated GIF, to
      #   process, of at least 0, from when it is uploaded, as {await_processing} counts them, or Float::INFINITY to
      #   wait for as long as processing takes
      # @param media_type [String, nil] the MIME type of media uploaded in chunks, inferred from the media and
      #   category when nil; an upload in a single request sends no type, since the API types the media itself, so
      #   one given for an image is not sent
      # @param chunk_size [Integer, nil] the size of each chunk of media uploaded in chunks, in bytes, of at most
      #   5,242,880, the 5 megabytes the API takes in a segment, derived from the size of the media when nil, so that
      #   an upload of up to the 16 gigabytes the API takes fits the segments it numbers
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @return [UploadedMedia] the uploaded media, which holds the upload response, or the processing status of
      #   media that X processes
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds a NUL byte or a
      #   line break, as the contents of media given in place of its path do
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMedia] if the media is larger than the API takes of its category, whatever the account: 5
      #   megabytes of an image, 15 of a GIF, and one of subtitles, or larger than the 16 gigabytes it takes of any
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or longer than the API takes,
      #   the chunk size is not a positive Integer, is larger than a segment the API takes, or would need more
      #   segments than the API numbers, the concurrency is not 1 to MAX_CONCURRENCY, or the processing timeout is not
      #   a number of seconds of at least 0
      # @raise [InvalidMediaType] if no media category is given for media whose type neither its bytes nor the name of
      #   its file names, if media uploaded in chunks is given no media type and none can be inferred, if the category does not
      #   take the type of the media, such as an MP4 video uploaded as a GIF, or if the file is named as a type every
      #   file of which begins with a signature, such as a PNG, and does not begin with it
      # @raise [MissingMediaData] if a response of the upload holds no media, or carries no body at all
      # @raise [ChunkedUploadFailed] if media uploaded in chunks is initialized, but a chunk cannot be appended, or it
      #   cannot be finalized, with the media it initialized
      # @raise [MediaProcessingFailed] if the media fails to process, or its processing ends in no state X documents
      # @raise [MediaProcessingTimeout] if the media is still processing once processing_timeout seconds would pass
      # @raise [MediaProcessingCheckFailed] if the media is uploaded, but a check of its processing fails, as when the
      #   API answers it with an error, with the media it uploaded
      # @raise [AltTextFailed] if the media is uploaded, but its alt text cannot be added, with the media it uploaded
      # @example Upload an image
      #   Uploader::MediaUpload.upload("image.png", client: client)
      # @example Upload an image with alt text
      #   Uploader::MediaUpload.upload("cat.jpg", client: client, alt_text: "A cat asleep on a keyboard")
      # @example Upload a video and wait until it can be attached to a post
      #   Uploader::MediaUpload.upload("video.mp4", client: client)
      # @example Upload an image held in memory, whose category its signature names
      #   Uploader::MediaUpload.upload(StringIO.new(png), client: client)
      def upload(media, client:, media_category: nil, alt_text: nil,
        processing_timeout: DEFAULT_PROCESSING_TIMEOUT, media_type: nil, chunk_size: nil, concurrency: DEFAULT_CONCURRENCY)
        source = Source.for(media)
        media_category = Validator.validate_upload!(source, media_category, alt_text:, chunk_size:, concurrency:, processing_timeout:) { Inference.infer_media_category(source) }
        uploaded = if Inference.chunked_upload?(source, media_category)
          # The media is passed on as the Source it was resolved to, which the signatures keep out of what media is
          chunked_upload(_ = source, client:, media_category:, media_type:, chunk_size:, concurrency:)
        else
          upload_binary(Inference.single_request!(source, media_category), client:, media_category:)
        end
        uploaded = Utils.processed!(uploaded.processing? ? MediaProcessingCheckFailed.__send__(:keeping, uploaded) { await_processing(uploaded, client:, processing_timeout:) } : uploaded)
        AltTextFailed.__send__(:keeping, uploaded) { Metadata.add_alt_text(uploaded, alt_text, client:) } unless alt_text.nil?
        uploaded
      end

      # Upload binary content to the X API
      #
      # @api public
      # @param content [String] the binary content to upload
      # @param client [Client] the X API client
      # @param media_category [String, Symbol] the media category, which content cannot be inferred from, in any case
      # @return [UploadedMedia] the uploaded media, which holds the upload response
      # @raise [ArgumentError] if the media category is invalid, or is that of a video or subtitles, which the API
      #   takes in chunks alone
      # @raise [InvalidMedia] if the content is empty, or larger than the API takes of its category or in a single
      #   request, which takes 5 megabytes, so that a larger GIF uploads with upload or chunked_upload
      # @raise [InvalidMediaType] if the signature of the content names a type the category does not take, or names
      #   none for a GIF category; content no signature names is sent for an image category, for the API to type
      # @raise [MissingMediaData] if the response holds no media, or carries no body at all
      # @example Upload binary content
      #   Uploader::MediaUpload.upload_binary(data, client: client, media_category: "tweet_image")
      def upload_binary(content, client:, media_category:)
        media_category = Validator.validate_media_category!(media_category)
        raise ArgumentError, "#{media_category} uploads in chunks alone: pass the file to upload or chunked_upload" if CHUNKED_CATEGORIES.include?(media_category)

        source = Source::Buffer.new(content)
        Validator.validate_single_request!(source, media_category)
        Inference.single_request!(source, media_category)

        boundary = SecureRandom.hex
        upload_body = Multipart.body("media", content, boundary:, media_category:)
        UploadedMedia.new(Utils.media_data(client.post("media/upload", upload_body, headers: Multipart.headers(boundary), **JSON_CLASSES), "of the upload"))
      end

      # Perform a chunked upload for large files
      #
      # @api public
      # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
      # @param client [Client] the X API client
      # @param media_category [String, Symbol, nil] the media category, in any case, inferred from the media when nil
      # @param media_type [String, nil] the MIME type of the media, sent as it is given, or inferred from the media and
      #   category when nil
      # @param chunk_size [Integer, nil] the size of each chunk in bytes, of at most 5,242,880, the 5 megabytes the API
      #   takes in a segment, derived from the size of the media when nil: a megabyte, or as much more, up to 5, as the
      #   segments the API numbers ask
      # @param concurrency [Integer] the number of chunks uploaded at once, of 1 to MAX_CONCURRENCY
      # @return [UploadedMedia] the uploaded media, which holds the upload response
      # @raise [ArgumentError] if the media is neither a path nor an IO, or is a String that holds a NUL byte or a
      #   line break, as the contents of media given in place of its path do
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [InvalidMedia] if the media cannot be read, or is empty, which holds nothing to upload
      # @raise [InvalidMedia] if the media is larger than the API takes of its category, which is 15 megabytes of a
      #   GIF and one of subtitles, or larger than the 16 gigabytes it takes of any
      # @raise [ArgumentError] if the media category is invalid, the chunk size is not a positive Integer, is
      #   larger than a segment the API takes, or would need more segments than the API numbers, or the concurrency is
      #   not 1 to MAX_CONCURRENCY
      # @raise [InvalidMediaType] if no media type is given and none can be inferred, or the one the media is, read
      #   from its bytes or else from the name of its file, is not one the category takes
      # @raise [MissingMediaData] if the response that initializes the upload holds no media to append the chunks to
      # @raise [ChunkedUploadFailed] if the upload is initialized, but a chunk cannot be appended, or it cannot be
      #   finalized, or the response that finalizes it holds no media or carries no body at all, with the media it
      #   initialized, and the error that failed it as the cause
      # @example Upload a large video
      #   Uploader::MediaUpload.chunked_upload("video.mp4", client: client)
      def chunked_upload(media, client:, media_category: nil, media_type: nil, chunk_size: nil, concurrency: DEFAULT_CONCURRENCY)
        source = Source.for(media)
        Validator.validate_source!(source)
        media_category = Validator.validate_media_category!(media_category || Inference.infer_media_category(source))
        Validator.validate_size!(source, media_category)
        Validator.validate_chunks!(chunk_size:, concurrency:)
        chunk_size = Validator.validate_segments!(source, chunk_size)
        media_type ||= Inference.infer_media_type(source, media_category)
        uploaded = Chunks.init(client:, source:, media_type:, media_category:)
        ChunkedUploadFailed.__send__(:keeping, uploaded) { Chunks.complete(client:, source:, chunk_size:, media: uploaded, concurrency:) }
      end

      # Wait for media processing to complete
      #
      # Before each check it waits as long as X asked, and at least a second: media an upload returned, or the Hash
      # of its response, which says how long to wait before the first check, is not checked until then, and media
      # given as its identifier, or as media that says nothing of its processing, is checked at once.
      #
      # The processing timeout is a deadline, the seconds from when it is called, measured on the monotonic clock, so
      # that it counts the time each check takes, with any wait for a rate limit and any retry the client makes, as
      # well as the waits between them. It gives up once the next check X asks for would come after the deadline,
      # rather than sleep past it, or check before X asks. A check under way at the deadline is let finish, and its
      # status returned if processing has finished, so it can return that much after the deadline.
      #
      # It waits while the processing is pending or in progress alone, so a status whose processing names no state, or
      # a state X does not document, is returned as it is, neither processing nor ready, rather than checked until the
      # deadline, since X gives no time to check it again at; await_processing! raises for it.
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param client [Client] the X API client
      # @param processing_timeout [Integer, Float] the seconds from now to wait for processing to finish, checks and
      #   all, before giving up, or Float::INFINITY to wait for as long as processing takes
      # @return [UploadedMedia] the uploaded media, which holds the processing status
      # @raise [ArgumentError] if the processing timeout is not a number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingTimeout] if the media is still processing once the next check would pass the deadline
      # @example Wait for processing
      #   Uploader::MediaUpload.await_processing(media, client: client)
      # @example Wait for the processing of media known by its identifier
      #   Uploader::MediaUpload.await_processing("1880028106020515840", client: client)
      # @example Wait up to half an hour for a long video
      #   Uploader::MediaUpload.await_processing(media, client: client, processing_timeout: 1800)
      def await_processing(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        Validator.validate_processing_timeout!(processing_timeout)
        uploaded = Utils.uploaded_media(media)
        deadline, media_id = Utils.seconds_from_now(processing_timeout), Utils.media_id(uploaded)
        pending = uploaded if uploaded.processing?
        loop do
          Utils.wait_to_check(pending, deadline:, timeout: processing_timeout) if pending
          status = UploadedMedia.new(Utils.media_data(client.get("media/upload", params: {command: STATUS_COMMAND, media_id:}, **JSON_CLASSES), "of the status check"))
          return status unless status.processing?

          pending = status
        end
      end

      # Wait for media processing and raise on failure
      #
      # @api public
      # @param media [UploadedMedia, Hash, #media_key, String, Integer] the uploaded media, media that has a media key,
      #   such as X::Media, the media key, or the media identifier
      # @param client [Client] the X API client
      # @param processing_timeout [Integer, Float] the seconds from now to wait for processing to finish, checks and
      #   all, before giving up, as {await_processing} counts them, or Float::INFINITY to wait for as long as
      #   processing takes
      # @return [UploadedMedia] the uploaded media, which holds the processing status
      # @raise [ArgumentError] if the processing timeout is not a number of seconds of at least 0
      # @raise [ArgumentError] if the media given is nil, holds no identifier, or is neither media, a media key, nor a
      #   media identifier, or its media key names none
      # @raise [MissingMediaData] if a status response holds no media or carries no body at all
      # @raise [MediaProcessingFailed] if media processing failed, or ended in no state X documents, with the status X
      #   reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the next check would pass the deadline
      # @example Wait for processing with error handling
      #   Uploader::MediaUpload.await_processing!(media, client: client)
      def await_processing!(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        Utils.processed!(await_processing(media, client:, processing_timeout:))
      end

      # Infers how media uploads: in chunks or whole, in which category, and as which type
      #
      # Internal to x-uploader: the methods of MediaUpload decide with it how to send media, by rules that follow
      # what the API takes and X processes, so that they can change within 1.x as those do. It is a module of its own,
      # rather than private methods of MediaUpload, so that a class that includes MediaUpload gains none of them, and
      # no method the class defines under the same name changes an upload.
      #
      # @api private
      module Inference
        extend self

        # Check whether a file uploads in chunks rather than in a single request
        #
        # A video and subtitles upload in chunks whatever their size, since the API takes them no other way, and an
        # animated GIF uploads in chunks once it is larger than MAX_SIMPLE_UPLOAD_BYTES, which a single request takes
        # no more of; the API takes a GIF of up to 15 MB in chunks. An image uploads in a single request.
        #
        # upload decides with it how to send media.
        #
        # @api private
        # @param media [String, Pathname, IO, StringIO] the path to the media to upload, or an IO open on it
        # @param media_category [String, Symbol] the media category, in any case
        # @return [Boolean] true if the media uploads in chunks
        # @raise [Errno::ENOENT] if a GIF file does not exist
        # @example Check whether a large animated GIF uploads in chunks
        #   Inference.chunked_upload?("cat.gif", "tweet_gif") # => true
        def chunked_upload?(media, media_category)
          category = media_category.to_s.downcase
          CHUNKED_CATEGORIES.include?(category) || (GIF_CATEGORIES.include?(category) && Source.for(media).size > MAX_SIMPLE_UPLOAD_BYTES)
        end

        # Infer the media category of a post attachment from the media
        #
        # Media is categorized by its type, which {media_type_of} reads from the bytes it begins with, or else from the
        # extension of the name of its file, so that a file named as what it is not is categorized as what it is. A
        # GIF with a single frame is an image, since X processes only animated GIFs as GIFs.
        #
        # upload infers the category of media it is given none for with it.
        #
        # @api private
        # @param media [String, Pathname, IO, StringIO] the path to the media, or an IO open on it
        # @return [String] tweet_gif, tweet_video for MP4, QuickTime, WebM, or MPEG-TS, subtitles for SubRip or WebVTT, or tweet_image
        # @raise [InvalidMediaType] if neither the bytes of the media nor the name of its file names its type, or its
        #   file is named as a type whose signature it does not begin with
        # @example Infer the category of a video
        #   Inference.infer_media_category("cat.mp4") # => "tweet_video"
        # @example Infer the category of an animated GIF held in memory
        #   Inference.infer_media_category(StringIO.new(gif)) # => "tweet_gif"
        def infer_media_category(media)
          source = Source.for(media)
          documented!(source)
          type = media_type_of(source) or raise InvalidMediaType, "unable to determine the media type of #{source.description}: pass media_category"
          category = TYPE_CATEGORIES.fetch(type, TWEET_IMAGE)
          # A GIF of a single frame is an image, which its category is read again as. A GIF larger than the API takes
          # of any GIF is not read, since it is refused whether it is animated or not, and reading it would hold it all
          still = category.eql?(TWEET_GIF) && source.readable? && source.size <= MAX_GIF_BYTES && !Gif.animated?(source)
          still ? TWEET_IMAGE : category
        end

        # Infer the media type from the media and its category
        #
        # Media is uploaded as its type, which {media_type_of} reads, when the category takes that type, and raises
        # when it does not, rather than be sent as a type it is not, such as an MP4 video as a GIF. Media whose type
        # cannot be read is uploaded as the first type of a video or subtitles category, MP4 or SubRip, which may
        # begin with no signature that names them, and raises for any other category.
        #
        # A chunked upload infers the type of media it is given none for with it.
        #
        # @api private
        # @param media [String, Pathname, IO, StringIO] the path to the media, or an IO open on it
        # @param media_category [String, Symbol] the media category, in any case
        # @return [String] the inferred MIME type
        # @raise [InvalidMediaType] if the category does not take the type of the media, or the MIME type cannot be determined
        # @example Inference.infer_media_type("image.png", "tweet_image") #=> "image/png"
        # @example Inference.infer_media_type("clip.webm", "tweet_video") #=> "video/webm"
        def infer_media_type(media, media_category)
          source = Source.for(media)
          documented!(source)
          category = media_category.to_s.downcase
          taken_type(source, category) ||
            (CATEGORY_MIME_TYPES.fetch(category).first if CHUNKED_CATEGORIES.include?(category)) ||
            raise(InvalidMediaType, "unable to determine the MIME type of #{source.description}")
        end

        # Refuse media to upload in a single request as a category that does not take it
        #
        # Media of a type the category does not take raises, as does media of no known type for a GIF category, since
        # every GIF begins with its signature. Media of no known type is sent for an image category, since the API
        # types what a single request sends itself, and takes images, such as HEIC photos, no signature here names.
        #
        # upload and upload_binary check what they send in a single request with it, upload by the name of the file
        # as well as by its bytes, before it reads the whole of the media.
        #
        # @api private
        # @param source [Source] the media
        # @param media_category [String] the media category, in lowercase
        # @return [String] the whole of the media, to send
        # @raise [InvalidMediaType] if the category does not take the media
        def single_request!(source, media_category)
          documented!(source)
          return source.content if taken_type(source, media_category) || !GIF_CATEGORIES.include?(media_category)

          raise InvalidMediaType, "#{source.description} is not a GIF, which #{media_category} media must be"
        end

        # The type of media, once its category is known to take it
        #
        # @api private
        # @param source [Source] the media
        # @param media_category [String] the media category, in lowercase
        # @return [String, nil] the MIME type, or nil for media whose type cannot be read
        # @raise [InvalidMediaType] if the category does not take the type of the media
        def taken_type(source, media_category)
          type = media_type_of(source)
          return type if type.nil? || CATEGORY_MIME_TYPES.fetch(media_category).include?(type)

          raise InvalidMediaType, "#{source.description} is #{type}, which #{media_category} media is not: pass the " \
            "media_category of what it is, or the media_type to send it as to chunked_upload"
        end

        # The MIME type of media, read from its bytes, or else from the name of its file
        #
        # The bytes name the type when a signature is read from them, whatever the file is named, and the extension of
        # the name names it otherwise, as it does for media that cannot be read. A file named as a type every file of
        # which begins with a signature, such as a PNG, is not that type when it begins with none.
        #
        # @api private
        # @param source [Source] the media
        # @return [String, nil] the MIME type, or nil if neither the bytes nor the name names one
        # @raise [InvalidMediaType] if the file is named as a type whose signature it does not begin with
        def media_type_of(source)
          named = MIME_TYPE_MAP[source.extension]
          return named unless source.readable?

          sniffed = Signature.media_type(source.sniff)
          return sniffed || named unless sniffed.nil? && SIGNED_MIME_TYPES.include?(named)

          raise InvalidMediaType, "#{source.description} is named as #{named}, but does not begin with the bytes every " \
            "#{named} file begins with"
        end

        # Refuse a video of a container the API documents no media type for, or a 3D model
        #
        # An AVI or Matroska file is a video X documents no type for, so it is refused before a request, rather than
        # be sent as a type it is not, unless it begins with the signature of a type the API documents, as a WebM
        # video named .mkv does. Media whose name names no type, such as a StringIO or a Tempfile, is refused too when
        # it begins with the header of Matroska and is not WebM, since a video category would otherwise send it as MP4.
        # A .glb or .usdz file is a 3D model, which no media category takes, so it is refused whatever it holds.
        #
        # @api private
        # @param source [Source] the media
        # @return [void]
        # @raise [InvalidMediaType] if the media is a 3D model, or of such a container and no signature names its type
        def documented!(source)
          model = UNDOCUMENTED_MODELS[source.extension]
          raise InvalidMediaType, "no media category the API documents takes a #{model} 3D model, such as #{source.description}" if model

          container = UNDOCUMENTED_VIDEOS.fetch(source.extension) { "Matroska" if matroska?(source) }
          return if container.nil? || (source.readable? && Signature.media_type(source.sniff))

          raise InvalidMediaType, "the API documents no media type for #{container} video, such as #{source.description}: " \
            "convert it to MP4, QuickTime, WebM, or MPEG-TS"
        end

        # Whether media whose name names no type begins with the header of Matroska
        # @api private
        # @param source [Source] the media
        # @return [Boolean] true if the name of the media names no type and the media is Matroska
        def matroska?(source)
          !MIME_TYPE_MAP.key?(source.extension) && source.readable? && Signature.matroska?(source.sniff)
        end
      end
      private_constant :Inference
    end
  end
end
