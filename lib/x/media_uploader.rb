require "json"
require "securerandom"
require "tmpdir"
require_relative "media_upload_validator"

module X
  # Uploads media files to the X API
  # @api public
  module MediaUploader
    extend self

    # Maximum number of retry attempts for failed uploads
    MAX_RETRIES = 3
    # Number of bytes per megabyte
    BYTES_PER_MB = 1_048_576
    # Media category constants
    DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = MediaUploadValidator::MEDIA_CATEGORIES
    # Default MIME type for uploads
    DEFAULT_MIME_TYPE = "application/octet-stream".freeze
    # Supported MIME types
    MIME_TYPES = %w[image/gif image/jpeg video/mp4 image/png application/x-subrip image/webp].freeze
    # MIME type constants
    GIF_MIME_TYPE, JPEG_MIME_TYPE, MP4_MIME_TYPE, PNG_MIME_TYPE, SUBRIP_MIME_TYPE, WEBP_MIME_TYPE = MIME_TYPES
    # Mapping of file extensions to MIME types
    MIME_TYPE_MAP = {"gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "mp4" => MP4_MIME_TYPE,
                     "png" => PNG_MIME_TYPE, "srt" => SUBRIP_MIME_TYPE, "webp" => WEBP_MIME_TYPE}.freeze
    # Processing states that indicate completion
    PROCESSING_INFO_STATES = %w[failed succeeded].freeze

    # Upload a file to the X API
    #
    # @api public
    # @param client [Client] the X API client
    # @param file_path [String] the path to the file to upload
    # @param media_category [String] the media category
    # @param boundary [String] the multipart boundary
    # @return [Hash, nil] the upload response data
    # @raise [RuntimeError] if the file does not exist
    # @example Upload an image
    #   MediaUploader.upload(client: client, file_path: "image.png", media_category: "tweet_image")
    def upload(client:, file_path:, media_category:, boundary: SecureRandom.hex)
      MediaUploadValidator.validate_file_path!(file_path:)
      upload_binary(client:, content: File.binread(file_path), media_category:, boundary:)
    end

    # Upload binary content to the X API
    #
    # @api public
    # @param client [Client] the X API client
    # @param content [String] the binary content to upload
    # @param media_category [String] the media category
    # @param boundary [String] the multipart boundary
    # @return [Hash, nil] the upload response data
    # @raise [ArgumentError] if the media category is invalid
    # @example Upload binary content
    #   MediaUploader.upload_binary(client: client, content: data, media_category: "tweet_image")
    def upload_binary(client:, content:, media_category:, boundary: SecureRandom.hex)
      MediaUploadValidator.validate_media_category!(media_category:)
      upload_body = construct_upload_body(content:, media_category:, boundary:)
      headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
      client.post("media/upload", upload_body, headers:)&.fetch("data")
    end

    # Perform a chunked upload for large files
    #
    # @api public
    # @param client [Client] the X API client
    # @param file_path [String] the path to the file to upload
    # @param media_category [String] the media category
    # @param media_type [String] the MIME type of the media
    # @param boundary [String] the multipart boundary
    # @param chunk_size_mb [Integer] the size of each chunk in megabytes
    # @return [Hash, nil] the upload response data
    # @raise [RuntimeError] if the file does not exist
    # @raise [ArgumentError] if the media category is invalid
    # @example Upload a large video
    #   MediaUploader.chunked_upload(client: client, file_path: "video.mp4", media_category: "tweet_video")
    def chunked_upload(client:, file_path:, media_category:, media_type: infer_media_type(file_path, media_category),
      boundary: SecureRandom.hex, chunk_size_mb: 1)
      MediaUploadValidator.validate_file_path!(file_path:)
      MediaUploadValidator.validate_media_category!(media_category:)
      media = init(client:, file_path:, media_type:, media_category:)
      chunk_size = chunk_size_mb * BYTES_PER_MB
      append(client:, file_paths: split(file_path, chunk_size), media:, boundary:)
      client.post("media/upload/#{media["id"]}/finalize")&.fetch("data")
    end

    # Wait for media processing to complete
    #
    # @api public
    # @param client [Client] the X API client
    # @param media [Hash] the media object with an id
    # @return [Hash, nil] the processing status
    # @example Wait for processing
    #   MediaUploader.await_processing(client: client, media: media)
    def await_processing(client:, media:)
      loop do
        status = client.get("media/upload?command=STATUS&media_id=#{media["id"]}")&.fetch("data")
        return status if status.nil? || !status["processing_info"] || PROCESSING_INFO_STATES.include?(status["processing_info"]["state"])

        sleep status["processing_info"]["check_after_secs"].to_i
      end
    end

    # Wait for media processing and raise on failure
    #
    # @api public
    # @param client [Client] the X API client
    # @param media [Hash] the media object with an id
    # @return [Hash, nil] the processing status
    # @raise [RuntimeError] if media processing failed
    # @example Wait for processing with error handling
    #   MediaUploader.await_processing!(client: client, media: media)
    def await_processing!(client:, media:)
      status = await_processing(client:, media:)
      raise "Media processing failed" if status&.dig("processing_info", "state") == "failed"

      status
    end

    private

    # Infer the media type from file path and category
    # @api private
    # @param file_path [String] the file path
    # @param media_category [String] the media category
    # @return [String] the inferred MIME type
    def infer_media_type(file_path, media_category)
      case media_category.downcase
      when TWEET_GIF, DM_GIF then GIF_MIME_TYPE
      when TWEET_VIDEO, DM_VIDEO then MP4_MIME_TYPE
      when SUBTITLES then SUBRIP_MIME_TYPE
      else MIME_TYPE_MAP.fetch(File.extname(file_path).delete(".").downcase, DEFAULT_MIME_TYPE)
      end
    end

    # Split a file into chunks
    # @api private
    # @param file_path [String] the file path
    # @param chunk_size [Integer] the chunk size in bytes
    # @return [Array<String>] the paths to the chunk files
    def split(file_path, chunk_size)
      file_size = File.size(file_path)
      segment_count = (file_size.to_f / chunk_size).ceil
      (0...segment_count).map do |segment_index|
        segment_path = "#{Dir.mktmpdir}/x#{format("%03d", segment_index + 1)}"
        File.binwrite(segment_path, File.binread(file_path, chunk_size, segment_index * chunk_size))
        segment_path
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
      total_bytes = File.size(file_path)
      data = {media_type:, media_category:, total_bytes:}.to_json
      client.post("media/upload/initialize", data)&.fetch("data")
    end

    # Append chunks to a chunked upload
    # @api private
    # @param client [Client] the X API client
    # @param file_paths [Array<String>] the chunk file paths
    # @param media [Hash] the media object
    # @param boundary [String] the multipart boundary
    # @return [void]
    def append(client:, file_paths:, media:, boundary: SecureRandom.hex)
      threads = file_paths.map.with_index do |file_path, index|
        Thread.new do
          upload_body = construct_upload_body(content: File.binread(file_path), segment_index: index, boundary:)
          headers = {"Content-Type" => "multipart/form-data; boundary=#{boundary}"}
          upload_chunk(client:, media_id: media["id"], upload_body:, file_path:, headers:)
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
    def upload_chunk(client:, media_id:, upload_body:, file_path:, headers: {})
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
    def construct_upload_body(content:, media_category: nil, segment_index: nil, boundary: SecureRandom.hex)
      body = ""
      body += "--#{boundary}\r\nContent-Disposition: form-data; name=\"segment_index\"\r\n\r\n#{segment_index}\r\n" if segment_index
      body += "--#{boundary}\r\nContent-Disposition: form-data; name=\"media_category\"\r\n\r\n#{media_category}\r\n" if media_category
      "#{body}--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"media\"\r\n" \
        "Content-Type: #{DEFAULT_MIME_TYPE}\r\n\r\n" \
        "#{content}\r\n" \
        "--#{boundary}--\r\n"
    end
  end
end
