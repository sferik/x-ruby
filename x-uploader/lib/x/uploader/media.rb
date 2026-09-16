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
require_relative "validator"
require_relative "version"

module X
  module Uploader
    # Uploads media files to the X API
    # @api public
    module Media
      extend self
      extend Chunks

      # Number of bytes per megabyte
      BYTES_PER_MB = 1_048_576
      # Media category constants
      AMPLIFY_VIDEO, DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = Uploader::Validator::MEDIA_CATEGORIES
      # Supported MIME types: every media type the API documents for an upload
      MIME_TYPES = %w[image/bmp image/gif image/jpeg image/pjpeg image/png image/tiff image/webp model/gltf-binary
        model/vnd.usdz+zip text/srt text/vtt video/mp2t video/mp4 video/quicktime video/webm].freeze
      # MIME type constants
      BMP_MIME_TYPE, GIF_MIME_TYPE, JPEG_MIME_TYPE, PJPEG_MIME_TYPE, PNG_MIME_TYPE, TIFF_MIME_TYPE, WEBP_MIME_TYPE,
        GLTF_BINARY_MIME_TYPE, USDZ_MIME_TYPE, SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE, MPEG_TS_MIME_TYPE, MP4_MIME_TYPE,
        QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE = MIME_TYPES
      # Mapping of file extensions to MIME types
      MIME_TYPE_MAP = {
        "bmp" => BMP_MIME_TYPE, "gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "pjp" => PJPEG_MIME_TYPE,
        "pjpeg" => PJPEG_MIME_TYPE, "png" => PNG_MIME_TYPE, "tif" => TIFF_MIME_TYPE, "tiff" => TIFF_MIME_TYPE, "webp" => WEBP_MIME_TYPE,
        "glb" => GLTF_BINARY_MIME_TYPE, "usdz" => USDZ_MIME_TYPE, "srt" => SUBRIP_MIME_TYPE, "vtt" => WEBVTT_MIME_TYPE,
        "m2ts" => MPEG_TS_MIME_TYPE, "mts" => MPEG_TS_MIME_TYPE, "ts" => MPEG_TS_MIME_TYPE, "mp4" => MP4_MIME_TYPE,
        "mov" => QUICKTIME_MIME_TYPE, "qt" => QUICKTIME_MIME_TYPE, "webm" => WEBM_MIME_TYPE
      }.freeze
      # MIME types of the videos the API takes, the first of which a video of no known type is uploaded as
      VIDEO_MIME_TYPES = [MP4_MIME_TYPE, QUICKTIME_MIME_TYPE, WEBM_MIME_TYPE, MPEG_TS_MIME_TYPE].freeze
      # MIME types of the subtitles the API takes, the first of which subtitles of no known type are uploaded as
      SUBTITLES_MIME_TYPES = [SUBRIP_MIME_TYPE, WEBVTT_MIME_TYPE].freeze
      # Processing states that indicate completion
      PROCESSING_INFO_STATES = %w[failed succeeded].freeze
      # Default number of seconds await_processing waits between checks before it gives up
      DEFAULT_PROCESSING_TIMEOUT = 600
      # Fewest seconds to wait between checks, for a status that asks for no wait
      MIN_CHECK_AFTER_SECS = 1
      # Media categories that are uploaded in chunks and processed after the upload
      VIDEO_CATEGORIES = [AMPLIFY_VIDEO, DM_VIDEO, TWEET_VIDEO].freeze
      # Media categories uploaded in chunks: videos, and subtitles, which the API takes no other way
      CHUNKED_CATEGORIES = [*VIDEO_CATEGORIES, SUBTITLES].freeze
      # Mapping of file extensions to the media categories of posts; any other extension is an image
      CATEGORY_MAP = {
        "gif" => TWEET_GIF, "m2ts" => TWEET_VIDEO, "mov" => TWEET_VIDEO, "mp4" => TWEET_VIDEO, "mts" => TWEET_VIDEO,
        "qt" => TWEET_VIDEO, "ts" => TWEET_VIDEO, "webm" => TWEET_VIDEO, "srt" => SUBTITLES, "vtt" => SUBTITLES
      }.freeze
      # Mapping of media categories to the MIME types they take, the first by default; images are typed by their extension
      CATEGORY_MIME_TYPES = {
        TWEET_GIF => [GIF_MIME_TYPE], DM_GIF => [GIF_MIME_TYPE], TWEET_VIDEO => VIDEO_MIME_TYPES, DM_VIDEO => VIDEO_MIME_TYPES,
        AMPLIFY_VIDEO => VIDEO_MIME_TYPES, SUBTITLES => SUBTITLES_MIME_TYPES
      }.freeze
      private_constant :MIME_TYPES, :BMP_MIME_TYPE, :GIF_MIME_TYPE, :JPEG_MIME_TYPE, :PJPEG_MIME_TYPE, :PNG_MIME_TYPE,
        :TIFF_MIME_TYPE, :WEBP_MIME_TYPE, :GLTF_BINARY_MIME_TYPE, :USDZ_MIME_TYPE, :SUBRIP_MIME_TYPE, :WEBVTT_MIME_TYPE,
        :MPEG_TS_MIME_TYPE, :MP4_MIME_TYPE, :QUICKTIME_MIME_TYPE, :WEBM_MIME_TYPE, :MIME_TYPE_MAP, :VIDEO_MIME_TYPES,
        :SUBTITLES_MIME_TYPES, :PROCESSING_INFO_STATES, :MIN_CHECK_AFTER_SECS, :VIDEO_CATEGORIES, :CHUNKED_CATEGORIES,
        :CATEGORY_MAP, :CATEGORY_MIME_TYPES

      # Upload a file, in chunks for video and subtitles, awaiting any processing
      #
      # @api public
      # @param file_path [String] the path to the file to upload
      # @param client [Client] the X API client
      # @param media_category [String] the media category, inferred from the file by default
      # @param alt_text [String, nil] alt text describing the media, for people who cannot see it
      # @param boundary [String] the multipart boundary
      # @param processing_timeout [Integer] the seconds to wait for media, such as a video or an animated GIF, to process
      # @param options [Hash] options for a chunked upload, such as media_type, chunk_size_mb, and concurrency
      # @return [Hash, nil] the upload response data, or the processing status of media that X processes
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [MediaProcessingFailed] if the media fails to process
      # @raise [MediaProcessingTimeout] if the media is still processing after processing_timeout seconds
      # @example Upload an image
      #   Uploader::Media.upload("image.png", client: client)
      # @example Upload an image with alt text
      #   Uploader::Media.upload("cat.jpg", client: client, alt_text: "A cat asleep on a keyboard")
      # @example Upload a video and wait until it can be attached to a post
      #   Uploader::Media.upload("video.mp4", client: client)
      def upload(file_path, client:, media_category: infer_media_category(file_path), alt_text: nil, boundary: SecureRandom.hex,
        processing_timeout: DEFAULT_PROCESSING_TIMEOUT, **options)
        Validator.validate_file_path!(file_path)
        transfer(file_path, media_category, client:, boundary:, processing_timeout:, **options)
          .tap { |media| Metadata.add_alt_text(media, alt_text, client:) unless alt_text.nil? }
      end

      # Infer the media category of a post attachment from a file
      #
      # A GIF with a single frame is an image, since X processes only animated GIFs as GIFs.
      #
      # @api public
      # @param file_path [String] the path to the file
      # @return [String] tweet_gif, tweet_video for MP4, QuickTime, WebM, or MPEG-TS, subtitles for SubRip or WebVTT, or tweet_image
      # @example Infer the category of a video
      #   Uploader::Media.infer_media_category("cat.mp4") # => "tweet_video"
      def infer_media_category(file_path) = still_gif?(file_path) ? TWEET_IMAGE : CATEGORY_MAP.fetch(extension(file_path), TWEET_IMAGE)

      # Upload binary content to the X API
      #
      # @api public
      # @param content [String] the binary content to upload
      # @param client [Client] the X API client
      # @param media_category [String] the media category, which content cannot be inferred from
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] the upload response data
      # @raise [ArgumentError] if the media category is invalid
      # @example Upload binary content
      #   Uploader::Media.upload_binary(data, client: client, media_category: "tweet_image")
      def upload_binary(content, client:, media_category:, boundary: SecureRandom.hex)
        Validator.validate_media_category!(media_category)
        upload_body = construct_upload_body(content:, media_category:, boundary:)
        headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
        client.post("media/upload", upload_body, headers:, **JSON_CLASSES)&.fetch("data")
      end

      # Perform a chunked upload for large files
      #
      # @api public
      # @param file_path [String] the path to the file to upload
      # @param client [Client] the X API client
      # @param media_category [String] the media category, inferred from the file extension by default
      # @param media_type [String] the MIME type of the media
      # @param boundary [String] the multipart boundary
      # @param chunk_size_mb [Integer] the size of each chunk in megabytes
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [Hash, nil] the upload response data
      # @raise [Errno::ENOENT] if the file does not exist
      # @raise [ArgumentError] if the media category is invalid
      # @example Upload a large video
      #   Uploader::Media.chunked_upload("video.mp4", client: client)
      def chunked_upload(file_path, client:, media_category: infer_media_category(file_path),
        media_type: infer_media_type(file_path, media_category), boundary: SecureRandom.hex, chunk_size_mb: 1,
        concurrency: Chunks::DEFAULT_CONCURRENCY)
        Validator.validate_file_path!(file_path)
        Validator.validate_media_category!(media_category)
        media = init(client:, file_path:, media_type:, media_category:)
        append(client:, file_path:, chunk_size: chunk_size_mb * BYTES_PER_MB, media:, boundary:, concurrency:)
        client.post("media/upload/#{media.fetch("id")}/finalize", **JSON_CLASSES)&.fetch("data")
      end

      # Wait for media processing to complete
      #
      # Between checks it waits as long as X asks, and at least a second. It gives up, rather than wait past the
      # processing timeout, once those waits would add up to more than the processing timeout.
      #
      # @api public
      # @param media [Hash] the media object with an id
      # @param client [Client] the X API client
      # @param processing_timeout [Integer] the seconds to wait between checks, in all, before giving up
      # @return [Hash, nil] the processing status
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for processing
      #   Uploader::Media.await_processing(media, client: client)
      # @example Wait up to half an hour for a long video
      #   Uploader::Media.await_processing(media, client: client, processing_timeout: 1800)
      def await_processing(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        waited = 0
        loop do
          status = client.get("media/upload?command=STATUS&media_id=#{media.fetch("id")}", **JSON_CLASSES)&.fetch("data")
          processing_info = status&.dig("processing_info")
          return status if processing_info.nil? || PROCESSING_INFO_STATES.include?(processing_info["state"])

          wait = [processing_info["check_after_secs"].to_i, MIN_CHECK_AFTER_SECS].max
          raise MediaProcessingTimeout.new(status, processing_timeout) if (waited += wait) > processing_timeout

          sleep wait
        end
      end

      # Wait for media processing and raise on failure
      #
      # @api public
      # @param media [Hash] the media object with an id
      # @param client [Client] the X API client
      # @param processing_timeout [Integer] the seconds to wait between checks, in all, before giving up
      # @return [Hash, nil] the processing status
      # @raise [MediaProcessingFailed] if media processing failed, with the status X reported
      # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
      # @example Wait for processing with error handling
      #   Uploader::Media.await_processing!(media, client: client)
      def await_processing!(media, client:, processing_timeout: DEFAULT_PROCESSING_TIMEOUT)
        await_processing(media, client:, processing_timeout:).tap { |status| raise MediaProcessingFailed.new(status) if status&.dig("processing_info", "state").eql?("failed") }
      end

      # Infer the media type from file path and category
      #
      # A file whose extension names a type the category takes is uploaded as that type. A GIF category takes only
      # GIFs, and a video or subtitles category otherwise takes its first type, MP4 or SubRip, whatever the file is
      # named. Any other category, an image, is typed by its extension alone.
      #
      # @api public
      # @param file_path [String] the file path
      # @param media_category [String] the media category
      # @return [String] the inferred MIME type
      # @raise [InvalidMediaType] if the MIME type cannot be determined
      # @example Uploader::Media.infer_media_type("image.png", "tweet_image") #=> "image/png"
      # @example Uploader::Media.infer_media_type("clip.webm", "tweet_video") #=> "video/webm"
      def infer_media_type(file_path, media_category)
        from_extension = MIME_TYPE_MAP[extension(file_path)]
        taken = CATEGORY_MIME_TYPES.fetch(media_category.downcase, [from_extension])
        (taken.include?(from_extension) ? from_extension : taken.first) ||
          raise(InvalidMediaType, "unable to determine MIME type from file extension: #{file_path.inspect}")
      end

      private

      # Upload a file whole or in chunks, waiting for processing when the API reports it
      # @api private
      # @param file_path [String] the path to the file
      # @param media_category [String] the media category
      # @param client [Client] the X API client
      # @param boundary [String] the multipart boundary
      # @param processing_timeout [Integer] the seconds to wait for processing
      # @param options [Hash] options for a chunked upload
      # @return [Hash, nil] the upload response data, or the processing status
      def transfer(file_path, media_category, client:, boundary:, processing_timeout:, **options)
        media = if chunked?(media_category)
          chunked_upload(file_path, client:, media_category:, boundary:, **options)
        else
          upload_binary(File.binread(file_path), client:, media_category:, boundary:)
        end
        media&.key?("processing_info") ? await_processing!(media, client:, processing_timeout:) : media
      end

      # Check whether a media category is uploaded in chunks
      # @api private
      # @param media_category [String] the media category
      # @return [Boolean] true if the category is a video or subtitles
      def chunked?(media_category) = CHUNKED_CATEGORIES.include?(media_category.downcase)

      # Check whether a file is a GIF with a single frame
      # @api private
      # @param file_path [String] the path to the file
      # @return [Boolean] true if the file is a still GIF
      def still_gif?(file_path) = extension(file_path).eql?("gif") && File.file?(file_path) && !Gif.animated?(file_path)

      # The lowercase extension of a file, without its dot
      # @api private
      # @param file_path [String] the path to the file
      # @return [String] the extension
      def extension(file_path) = File.extname(file_path).delete(".").downcase
    end
  end
end
