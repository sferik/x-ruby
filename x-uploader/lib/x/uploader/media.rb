require "json"
require "securerandom"
require "x/core"
require_relative "chunks"
require_relative "gif"
require_relative "invalid_media_type"
require_relative "json_classes"
require_relative "media_processing_failed"
require_relative "media_processing_timeout"
require_relative "metadata"
require_relative "multipart"
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
    module Media
      extend self

      # Number of bytes per megabyte
      BYTES_PER_MB = Validator::BYTES_PER_MB
      # Greatest number of bytes the API takes in a single upload request, above which an animated GIF, which it
      # takes in chunks of up to 15 MB, uploads in chunks
      MAX_SIMPLE_UPLOAD_BYTES = 5 * BYTES_PER_MB
      # Media category constants
      AMPLIFY_VIDEO, DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = Validator::MEDIA_CATEGORIES
      # Supported MIME types: every media type the API documents for an upload
      MIME_TYPES = %w[image/bmp image/gif image/jpeg image/pjpeg image/png image/tiff image/webp model/gltf-binary
        model/vnd.usdz+zip text/srt text/vtt video/mp2t video/mp4 video/quicktime video/webm].map(&:freeze).freeze
      # MIME type constants
      BMP_MIME_TYPE, GIF_MIME_TYPE, JPEG_MIME_TYPE, PJPEG_MIME_TYPE, PNG_MIME_TYPE, TIFF_MIME_TYPE, WEBP_MIME_TYPE,
        GLTF_BINARY_MIME_TYPE, USDZ_MIME_TYPE, SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE, MPEG_TS_MIME_TYPE, MP4_MIME_TYPE,
        QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE = MIME_TYPES
      # Mapping of file extensions to MIME types
      MIME_TYPE_MAP = {
        "bmp" => BMP_MIME_TYPE, "gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "pjp" => PJPEG_MIME_TYPE,
        "pjpeg" => PJPEG_MIME_TYPE, "png" => PNG_MIME_TYPE, "tif" => TIFF_MIME_TYPE, "tiff" => TIFF_MIME_TYPE, "webp" => WEBP_MIME_TYPE,
        "glb" => GLTF_BINARY_MIME_TYPE, "usdz" => USDZ_MIME_TYPE, "srt" => SUBRIP_MIME_TYPE, "vtt" => WEBVTT_MIME_TYPE,
        "m2ts" => MPEG_TS_MIME_TYPE, "mts" => MPEG_TS_MIME_TYPE, "ts" => MPEG_TS_MIME_TYPE, "m4v" => MP4_MIME_TYPE,
        "mp4" => MP4_MIME_TYPE, "mov" => QUICKTIME_MIME_TYPE, "qt" => QUICKTIME_MIME_TYPE, "webm" => WEBM_MIME_TYPE
      }.freeze
      # MIME types of the videos the API takes, the first of which a video of no known type is uploaded as
      VIDEO_MIME_TYPES = [MP4_MIME_TYPE, QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE, MPEG_TS_MIME_TYPE].freeze
      # MIME types of the subtitles the API takes, the first of which subtitles of no known type are uploaded as
      SUBTITLES_MIME_TYPES = [SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE].freeze
      # Default number of seconds await_processing waits between checks before it gives up
      DEFAULT_PROCESSING_TIMEOUT = 600
      # Default number of chunks uploaded at once
      DEFAULT_CONCURRENCY = 4
      # Fewest seconds to wait between checks, for a status that asks for no wait
      MIN_CHECK_AFTER_SECS = 1
      # Media categories that are uploaded in chunks and processed after the upload
      VIDEO_CATEGORIES = [AMPLIFY_VIDEO, DM_VIDEO, TWEET_VIDEO].freeze
      # Media categories uploaded in chunks: videos, and subtitles, which the API takes no other way
      CHUNKED_CATEGORIES = [*VIDEO_CATEGORIES, SUBTITLES].freeze
      # Media categories of animated GIFs, which upload in chunks only when a single request cannot take them
      GIF_CATEGORIES = [DM_GIF, TWEET_GIF].freeze
      # Mapping of file extensions to the media categories of posts; any other extension is an image. An AVI or
      # Matroska file is a video, though the API documents no type for one, so that it uploads in chunks, as MP4,
      # rather than whole as an image, and X decides whether to process it.
      CATEGORY_MAP = {
        "avi" => TWEET_VIDEO, "gif" => TWEET_GIF, "m2ts" => TWEET_VIDEO, "m4v" => TWEET_VIDEO, "mkv" => TWEET_VIDEO,
        "mov" => TWEET_VIDEO, "mp4" => TWEET_VIDEO, "mts" => TWEET_VIDEO, "qt" => TWEET_VIDEO, "ts" => TWEET_VIDEO,
        "webm" => TWEET_VIDEO, "srt" => SUBTITLES, "vtt" => SUBTITLES
      }.freeze
      # Mapping of media categories to the MIME types they take, the first by default; images are typed by their extension
      CATEGORY_MIME_TYPES = {
        TWEET_GIF => [GIF_MIME_TYPE], DM_GIF => [GIF_MIME_TYPE], TWEET_VIDEO => VIDEO_MIME_TYPES, DM_VIDEO => VIDEO_MIME_TYPES,
        AMPLIFY_VIDEO => VIDEO_MIME_TYPES, SUBTITLES => SUBTITLES_MIME_TYPES
      }.freeze
      private_constant :MIME_TYPES, :BMP_MIME_TYPE, :GIF_MIME_TYPE, :JPEG_MIME_TYPE, :PJPEG_MIME_TYPE, :PNG_MIME_TYPE,
        :TIFF_MIME_TYPE, :WEBP_MIME_TYPE, :GLTF_BINARY_MIME_TYPE, :USDZ_MIME_TYPE, :SUBRIP_MIME_TYPE, :WEBVTT_MIME_TYPE,
        :MPEG_TS_MIME_TYPE, :MP4_MIME_TYPE, :QUICKTIME_MIME_TYPE, :WEBM_MIME_TYPE, :MIME_TYPE_MAP, :VIDEO_MIME_TYPES,
        :SUBTITLES_MIME_TYPES, :MIN_CHECK_AFTER_SECS, :VIDEO_CATEGORIES, :CHUNKED_CATEGORIES, :GIF_CATEGORIES,
        :CATEGORY_MAP, :CATEGORY_MIME_TYPES

      # Upload a file, in chunks when the API needs them, awaiting any processing
      #
      # A video and subtitles upload in chunks, as does an animated GIF that a single request cannot take. Every
      # argument is validated before the first request, so that no media is uploaded, and billed, for an upload
      # that cannot finish.
      #
      # @api public
      # @param file_path [String, Pathname] the path to the file to upload
      # @param client [Client] the X API client
      # @param media_category [String, Symbol] the media category, in any case, inferred from the file by default
      # @param alt_text [String, nil] alt text describing the media, for people who cannot see it, of 1 to 1,000 characters
      # @param processing_timeout [Integer] the seconds to wait for media, such as a video or an animated GIF, to process
      # @param media_type [String, nil] the MIME type of media uploaded in chunks, inferred from the file and category
      #   when nil; an upload in a single request sends no type, since the API types the media itself, so one given
      #   for an image is not sent
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk of media uploaded in chunks, in megabytes,
      #   derived from the size of the file when nil, so that an upload of any size fits the segments the API numbers
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [UploadedMedia, nil] the uploaded media, which holds the upload response, or the processing status of
      #   media that X processes
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [ArgumentError] if the media category is invalid, the alt text is empty or longer than the API takes,
      #   the chunk size is not positive or would need more segments than the API numbers, or the concurrency is
      #   less than one
      # @raise [InvalidMediaType] if media uploaded in chunks is given no media type and none can be inferred
      # @raise [MediaProcessingFailed] if the media fails to process
      # @raise [MediaProcessingTimeout] if the media is still processing after processing_timeout seconds
      # @example Upload an image
      #   Uploader::Media.upload("image.png", client: client)
      # @example Upload an image with alt text
      #   Uploader::Media.upload("cat.jpg", client: client, alt_text: "A cat asleep on a keyboard")
      # @example Upload a video and wait until it can be attached to a post
      #   Uploader::Media.upload("video.mp4", client: client)
      def upload(file_path, client:, media_category: infer_media_category(file_path), alt_text: nil,
        processing_timeout: DEFAULT_PROCESSING_TIMEOUT, media_type: nil, chunk_size_mb: nil, concurrency: DEFAULT_CONCURRENCY)
        media_category = Validator.validate_upload!(file_path, media_category, alt_text:, chunk_size_mb:, concurrency:)
        media = if chunked_upload?(file_path, media_category)
          chunked_upload(file_path, client:, media_category:, media_type:, chunk_size_mb:, concurrency:)
        else
          upload_binary(File.binread(file_path), client:, media_category:)
        end
        media = await_processing!(media, client:, processing_timeout:) if media&.key?("processing_info")
        Metadata.add_alt_text(media, alt_text, client:) unless media.nil? || alt_text.nil?
        media
      end

      # Check whether a file uploads in chunks rather than in a single request
      #
      # A video and subtitles upload in chunks whatever their size, since the API takes them no other way, and an
      # animated GIF uploads in chunks once it is larger than MAX_SIMPLE_UPLOAD_BYTES, which a single request takes
      # no more of; the API takes a GIF of up to 15 MB in chunks. An image uploads in a single request.
      #
      # @api public
      # @param file_path [String, Pathname] the path to the file to upload
      # @param media_category [String, Symbol] the media category, in any case
      # @return [Boolean] true if the file uploads in chunks
      # @raise [Errno::ENOENT] if a GIF file does not exist
      # @example Check whether a large animated GIF uploads in chunks
      #   Uploader::Media.chunked_upload?("cat.gif", "tweet_gif") # => true
      def chunked_upload?(file_path, media_category)
        category = media_category.to_s.downcase
        CHUNKED_CATEGORIES.include?(category) || (GIF_CATEGORIES.include?(category) && File.size(file_path) > MAX_SIMPLE_UPLOAD_BYTES)
      end

      # Infer the media category of a post attachment from a file
      #
      # A GIF with a single frame is an image, since X processes only animated GIFs as GIFs.
      #
      # @api public
      # @param file_path [String, Pathname] the path to the file
      # @return [String] tweet_gif, tweet_video for MP4, QuickTime, WebM, or MPEG-TS, subtitles for SubRip or WebVTT, or tweet_image
      # @example Infer the category of a video
      #   Uploader::Media.infer_media_category("cat.mp4") # => "tweet_video"
      def infer_media_category(file_path)
        category = CATEGORY_MAP.fetch(Utils.extension(file_path), TWEET_IMAGE)
        still = category.eql?(TWEET_GIF) && File.file?(file_path) && !Gif.animated?(file_path)
        still ? TWEET_IMAGE : category
      end

      # Upload binary content to the X API
      #
      # @api public
      # @param content [String] the binary content to upload
      # @param client [Client] the X API client
      # @param media_category [String, Symbol] the media category, which content cannot be inferred from, in any case
      # @return [UploadedMedia, nil] the uploaded media, which holds the upload response
      # @raise [ArgumentError] if the media category is invalid, or is amplify_video, which the API takes in chunks
      #   alone
      # @example Upload binary content
      #   Uploader::Media.upload_binary(data, client: client, media_category: "tweet_image")
      def upload_binary(content, client:, media_category:)
        media_category = Validator.validate_media_category!(media_category)
        raise ArgumentError, "amplify_video uploads in chunks alone: pass the file to upload or chunked_upload" if media_category.eql?(AMPLIFY_VIDEO)

        boundary = SecureRandom.hex
        upload_body = Multipart.body("media", content, boundary:, media_category:)
        UploadedMedia.from(client.post("media/upload", upload_body, headers: Multipart.headers(boundary), **JSON_CLASSES)&.fetch("data"))
      end

      # Perform a chunked upload for large files
      #
      # @api public
      # @param file_path [String, Pathname] the path to the file to upload
      # @param client [Client] the X API client
      # @param media_category [String, Symbol] the media category, in any case, inferred from the file extension by default
      # @param media_type [String, nil] the MIME type of the media, inferred from the file and category when nil
      # @param chunk_size_mb [Float, Integer, nil] the size of each chunk in megabytes, rounded up to a whole byte,
      #   derived from the size of the file when nil: a megabyte, or as much more as the segments the API numbers ask
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [UploadedMedia, nil] the uploaded media, which holds the upload response
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the file is empty, which holds nothing to upload
      # @raise [ArgumentError] if the media category is invalid, the chunk size is not positive or would need more
      #   segments than the API numbers, or the concurrency is less than one
      # @raise [InvalidMediaType] if no media type is given and none can be inferred
      # @example Upload a large video
      #   Uploader::Media.chunked_upload("video.mp4", client: client)
      def chunked_upload(file_path, client:, media_category: infer_media_category(file_path),
        media_type: nil, chunk_size_mb: nil, concurrency: DEFAULT_CONCURRENCY)
        Validator.validate_file_path!(file_path)
        media_category = Validator.validate_media_category!(media_category)
        Validator.validate_chunks!(chunk_size_mb:, concurrency:)
        chunk_size = Validator.validate_segments!(file_path, chunk_size_mb)
        media_type ||= infer_media_type(file_path, media_category)
        media = Chunks.init(client:, file_path:, media_type:, media_category:)
        Chunks.append(client:, file_path:, chunk_size:, media:, boundary: SecureRandom.hex, concurrency:)
        UploadedMedia.from(client.post("media/upload/#{media.fetch("id")}/finalize", **JSON_CLASSES)&.fetch("data"))
      end

      # Wait for media processing to complete
      #
      # Between checks it waits as long as X asks, and at least a second. It gives up, rather than wait past the
      # processing timeout, once those waits would add up to more than the processing timeout.
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param client [Client] the X API client
      # @param processing_timeout [Integer] the seconds to wait between checks, in all, before giving up
      # @return [UploadedMedia, nil] the uploaded media, which holds the processing status
      # @raise [KeyError] if an upload response has no id
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for processing
      #   Uploader::Media.await_processing(media, client: client)
      # @example Wait for the processing of media known by its identifier
      #   Uploader::Media.await_processing("1880028106020515840", client: client)
      # @example Wait up to half an hour for a long video
      #   Uploader::Media.await_processing(media, client: client, processing_timeout: 1800)
      def await_processing(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        waited = 0
        media_id = Utils.media_id(media)
        loop do
          status = UploadedMedia.from(client.get("media/upload?command=STATUS&media_id=#{media_id}", **JSON_CLASSES)&.fetch("data"))
          return status unless status&.processing?

          wait = [status.check_after_secs.to_i, MIN_CHECK_AFTER_SECS].max
          raise MediaProcessingTimeout.new(status, processing_timeout) if (waited += wait) > processing_timeout

          sleep wait
        end
      end

      # Wait for media processing and raise on failure
      #
      # @api public
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, or the media identifier
      # @param client [Client] the X API client
      # @param processing_timeout [Integer] the seconds to wait between checks, in all, before giving up
      # @return [UploadedMedia, nil] the uploaded media, which holds the processing status
      # @raise [KeyError] if an upload response has no id
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for processing with error handling
      #   Uploader::Media.await_processing!(media, client: client)
      def await_processing!(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        await_processing(media, client:, processing_timeout:).tap { |status| raise MediaProcessingFailed.new(status) if status&.failed? }
      end

      # Infer the media type from file path and category
      #
      # A file whose extension names a type the category takes is uploaded as that type. A GIF category takes only
      # GIFs, and a video or subtitles category otherwise takes its first type, MP4 or SubRip, whatever the file is
      # named. Any other category, an image, is typed by its extension alone.
      #
      # @api public
      # @param file_path [String, Pathname] the file path
      # @param media_category [String, Symbol] the media category, in any case
      # @return [String] the inferred MIME type
      # @raise [InvalidMediaType] if the MIME type cannot be determined
      # @example Uploader::Media.infer_media_type("image.png", "tweet_image") #=> "image/png"
      # @example Uploader::Media.infer_media_type("clip.webm", "tweet_video") #=> "video/webm"
      def infer_media_type(file_path, media_category)
        from_extension = MIME_TYPE_MAP[Utils.extension(file_path)]
        taken = CATEGORY_MIME_TYPES.fetch(media_category.to_s.downcase, [from_extension])
        (taken.include?(from_extension) ? from_extension : taken.first) ||
          raise(InvalidMediaType, "unable to determine MIME type from file extension: #{File.path(file_path).inspect}")
      end
    end
  end
end
