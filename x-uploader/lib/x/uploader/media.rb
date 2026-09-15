require "json"
require "securerandom"
require "tmpdir"
require "x/core"
require_relative "gif"
require_relative "invalid_media_type"
require_relative "metadata"
require_relative "validator"
require_relative "version"

module X
  module Uploader
    # Uploads media files to the X API
    # @api public
    module Media
      extend self

      # Maximum number of retry attempts for failed uploads
      MAX_RETRIES = 3
      # Number of bytes per megabyte
      BYTES_PER_MB = 1_048_576
      # Media category constants
      DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = Uploader::Validator::MEDIA_CATEGORIES
      # Supported MIME types
      MIME_TYPES = %w[image/gif image/jpeg video/mp4 image/png text/srt image/webp].freeze
      # MIME type constants
      GIF_MIME_TYPE, JPEG_MIME_TYPE, MP4_MIME_TYPE, PNG_MIME_TYPE, SUBRIP_MIME_TYPE, WEBP_MIME_TYPE = MIME_TYPES
      # Mapping of file extensions to MIME types
      MIME_TYPE_MAP = {"gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "mp4" => MP4_MIME_TYPE, "png" => PNG_MIME_TYPE, "srt" => SUBRIP_MIME_TYPE, "webp" => WEBP_MIME_TYPE}.freeze
      # Processing states that indicate completion
      PROCESSING_INFO_STATES = %w[failed succeeded].freeze
      # Media categories that are uploaded in chunks and processed after the upload
      VIDEO_CATEGORIES = [DM_VIDEO, TWEET_VIDEO].freeze
      # Media categories uploaded in chunks: videos, and subtitles, which the API takes no other way
      CHUNKED_CATEGORIES = [*VIDEO_CATEGORIES, SUBTITLES].freeze
      # Mapping of file extensions to the media categories of posts; any other extension is an image
      CATEGORY_MAP = {"gif" => TWEET_GIF, "mp4" => TWEET_VIDEO, "srt" => SUBTITLES}.freeze
      # Mapping of media categories to the MIME types they imply; images are typed by their extension
      CATEGORY_MIME_TYPES = {TWEET_GIF => GIF_MIME_TYPE, DM_GIF => GIF_MIME_TYPE, TWEET_VIDEO => MP4_MIME_TYPE, DM_VIDEO => MP4_MIME_TYPE, SUBTITLES => SUBRIP_MIME_TYPE}.freeze

      # Upload a file, in chunks for video and subtitles, awaiting any processing
      #
      # @api public
      # @param file_path [String] the path to the file to upload
      # @param client [Client] the X API client
      # @param media_category [String] the media category, inferred from the file by default
      # @param alt_text [String, nil] alt text describing the media, for people who cannot see it
      # @param boundary [String] the multipart boundary
      # @param options [Hash] options for a chunked upload, such as media_type and chunk_size_mb
      # @return [Hash, nil] the upload response data, or the processing status of a video
      # @raise [RuntimeError] if the file does not exist or a video fails to process
      # @example Upload an image
      #   Uploader::Media.upload("image.png", client: client)
      # @example Upload an image with alt text
      #   Uploader::Media.upload("cat.jpg", client: client, alt_text: "A cat asleep on a keyboard")
      # @example Upload a video and wait until it can be attached to a post
      #   Uploader::Media.upload("video.mp4", client: client)
      def upload(file_path, client:, media_category: infer_media_category(file_path), alt_text: nil, boundary: SecureRandom.hex, **options)
        Validator.validate_file_path!(file_path)
        transfer(file_path, media_category, client:, boundary:, **options).tap { |media| Metadata.add_alt_text(media, alt_text, client:) unless alt_text.nil? }
      end

      # Infer the media category of a post attachment from a file
      #
      # A GIF with a single frame is an image, since X processes only animated GIFs as GIFs.
      #
      # @api public
      # @param file_path [String] the path to the file
      # @return [String] tweet_gif, tweet_video, subtitles, or tweet_image
      # @example Infer the category of a video
      #   Uploader::Media.infer_media_category("cat.mp4") # => "tweet_video"
      def infer_media_category(file_path) = still_gif?(file_path) ? TWEET_IMAGE : CATEGORY_MAP.fetch(extension(file_path), TWEET_IMAGE)

      # Upload binary content to the X API
      #
      # @api public
      # @param content [String] the binary content to upload
      # @param media_category [String] the media category
      # @param client [Client] the X API client
      # @param boundary [String] the multipart boundary
      # @return [Hash, nil] the upload response data
      # @raise [ArgumentError] if the media category is invalid
      # @example Upload binary content
      #   Uploader::Media.upload_binary(data, "tweet_image", client: client)
      def upload_binary(content, media_category, client:, boundary: SecureRandom.hex)
        Validator.validate_media_category!(media_category)
        upload_body = construct_upload_body(content:, media_category:, boundary:)
        headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
        client.post("media/upload", upload_body, headers:)&.fetch("data")
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
      # @return [Hash, nil] the upload response data
      # @raise [RuntimeError] if the file does not exist
      # @raise [ArgumentError] if the media category is invalid
      # @example Upload a large video
      #   Uploader::Media.chunked_upload("video.mp4", client: client)
      def chunked_upload(file_path, client:, media_category: infer_media_category(file_path),
        media_type: infer_media_type(file_path, media_category), boundary: SecureRandom.hex, chunk_size_mb: 1)
        Validator.validate_file_path!(file_path)
        Validator.validate_media_category!(media_category)
        media = init(client:, file_path:, media_type:, media_category:)
        chunk_size = chunk_size_mb * BYTES_PER_MB
        append(client:, file_paths: split(file_path, chunk_size), media:, boundary:)
        client.post("media/upload/#{media.fetch("id")}/finalize")&.fetch("data")
      end

      # Wait for media processing to complete
      #
      # @api public
      # @param media [Hash] the media object with an id
      # @param client [Client] the X API client
      # @return [Hash, nil] the processing status
      # @example Wait for processing
      #   Uploader::Media.await_processing(media, client: client)
      def await_processing(media, client:)
        loop do
          status = client.get("media/upload?command=STATUS&media_id=#{media.fetch("id")}")&.fetch("data")
          processing_info = status&.dig("processing_info")
          return status if processing_info.nil? || PROCESSING_INFO_STATES.include?(processing_info["state"])

          sleep processing_info["check_after_secs"].to_i
        end
      end

      # Wait for media processing and raise on failure
      #
      # @api public
      # @param media [Hash] the media object with an id
      # @param client [Client] the X API client
      # @return [Hash, nil] the processing status
      # @raise [RuntimeError] if media processing failed
      # @example Wait for processing with error handling
      #   Uploader::Media.await_processing!(media, client: client)
      def await_processing!(media, client:)
        await_processing(media, client:).tap { |status| raise "Media processing failed" if status&.dig("processing_info", "state").eql?("failed") }
      end

      # Infer the media type from file path and category
      #
      # @api public
      # @param file_path [String] the file path
      # @param media_category [String] the media category
      # @return [String] the inferred MIME type
      # @raise [InvalidMediaType] if the MIME type cannot be determined
      # @example Uploader::Media.infer_media_type("image.png", "tweet_image") #=> "image/png"
      def infer_media_type(file_path, media_category)
        CATEGORY_MIME_TYPES.fetch(media_category.downcase) do
          MIME_TYPE_MAP.fetch(extension(file_path)) do
            raise InvalidMediaType, "unable to determine MIME type from file extension: #{file_path.inspect}"
          end
        end
      end

      private

      # Upload a file whole or in chunks, waiting for processing when the API reports it
      # @api private
      # @param file_path [String] the path to the file
      # @param media_category [String] the media category
      # @param client [Client] the X API client
      # @param boundary [String] the multipart boundary
      # @param options [Hash] options for a chunked upload
      # @return [Hash, nil] the upload response data, or the processing status
      def transfer(file_path, media_category, client:, boundary:, **options)
        return upload_binary(File.binread(file_path), media_category, client:, boundary:) unless chunked?(media_category)

        media = chunked_upload(file_path, client:, media_category:, boundary:, **options)
        media&.key?("processing_info") ? await_processing!(media, client:) : media
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

      # Split a file into chunks, each in its own temporary directory
      # @api private
      # @param file_path [String] the file path
      # @param chunk_size [Integer] the chunk size in bytes
      # @return [Array<String>] the paths to the chunk files
      def split(file_path, chunk_size)
        (0...File.size(file_path)).step(chunk_size).map do |offset|
          File.join(Dir.mktmpdir, "segment").tap { |segment_path| File.binwrite(segment_path, File.binread(file_path, chunk_size, offset)) }
        end
      end

      # Initialize a chunked upload
      # @api private
      # @param client [Client] the X API client
      # @param file_path [String] the file path
      # @param media_type [String] the MIME type
      # @param media_category [String] the media category
      # @return [Hash, nil] the initialization response
      def init(client:, file_path:, media_type:, media_category:)
        client.post("media/upload/initialize", {media_type:, media_category:, total_bytes: File.size(file_path)})&.fetch("data")
      end

      # Append chunks to a chunked upload
      # @api private
      # @param client [Client] the X API client
      # @param file_paths [Array<String>] the chunk file paths
      # @param media [Hash] the media object
      # @param boundary [String] the multipart boundary
      # @return [void]
      def append(client:, file_paths:, media:, boundary:)
        threads = file_paths.map.with_index do |file_path, index|
          Thread.new do
            upload_body = construct_upload_body(content: File.binread(file_path), segment_index: index, boundary:)
            headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
            upload_chunk(client:, media_id: media.fetch("id"), upload_body:, file_path:, headers:)
          end
        end
        threads.each(&:join)
      end

      # Upload a single chunk with retry logic
      # @api private
      # @param client [Client] the X API client
      # @param media_id [String] the media ID
      # @param upload_body [String] the upload body
      # @param file_path [String] the chunk file path
      # @param headers [Hash] the request headers
      # @return [void]
      def upload_chunk(client:, media_id:, upload_body:, file_path:, headers:)
        client.post("media/upload/#{media_id}/append", upload_body, headers:)
      rescue NetworkError, ServerError
        retries ||= 0
        ((retries += 1) < MAX_RETRIES) ? retry : raise
      ensure
        cleanup_file(file_path)
      end

      # Clean up a temporary file
      # @api private
      # @param file_path [String] the file path
      # @return [void]
      def cleanup_file(file_path)
        dirname = File.dirname(file_path)
        File.delete(file_path)
        Dir.delete(dirname) if Dir.empty?(dirname)
      end

      # Construct the multipart upload body
      # @api private
      # @param content [String] the content to upload
      # @param media_category [String, nil] the media category
      # @param segment_index [Integer, nil] the segment index
      # @param boundary [String] the multipart boundary
      # @return [String] the upload body
      def construct_upload_body(content:, boundary:, media_category: nil, segment_index: nil)
        body = ""
        body += "--#{boundary}\r\nContent-Disposition: form-data; name=\"segment_index\"\r\n\r\n#{segment_index}\r\n" if segment_index
        body += "--#{boundary}\r\nContent-Disposition: form-data; name=\"media_category\"\r\n\r\n#{media_category}\r\n" if media_category
        "#{body}--#{boundary}\r\n" \
          "Content-Disposition: form-data; name=\"media\"\r\n" \
          "Content-Type: application/octet-stream\r\n\r\n" \
          "#{content}\r\n" \
          "--#{boundary}--\r\n"
      end
    end
  end
end
