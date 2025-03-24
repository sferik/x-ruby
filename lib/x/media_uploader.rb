require "securerandom"
require "tmpdir"

module X
  module MediaUploader
    extend self

    MAX_RETRIES = 3
    BYTES_PER_MB = 1_048_576
    MEDIA_CATEGORIES = %w[dm_gif dm_image dm_video subtitles tweet_gif tweet_image tweet_video].freeze
    DM_GIF, DM_IMAGE, DM_VIDEO, SUBTITLES, TWEET_GIF, TWEET_IMAGE, TWEET_VIDEO = MEDIA_CATEGORIES
    DEFAULT_MIME_TYPE = "application/octet-stream".freeze
    MIME_TYPES = %w[image/gif image/jpeg video/mp4 image/png application/x-subrip image/webp].freeze
    GIF_MIME_TYPE, JPEG_MIME_TYPE, MP4_MIME_TYPE, PNG_MIME_TYPE, SUBRIP_MIME_TYPE, WEBP_MIME_TYPE = MIME_TYPES
    MIME_TYPE_MAP = {"gif" => GIF_MIME_TYPE, "jpg" => JPEG_MIME_TYPE, "jpeg" => JPEG_MIME_TYPE, "mp4" => MP4_MIME_TYPE,
                     "png" => PNG_MIME_TYPE, "srt" => SUBRIP_MIME_TYPE, "webp" => WEBP_MIME_TYPE}.freeze
    PROCESSING_INFO_STATES = %w[failed succeeded].freeze

    def upload(client:, file_path:, media_category:, media_type: infer_media_type(file_path, media_category),
      boundary: SecureRandom.hex)
      validate!(file_path:, media_category:)
      upload_body = construct_upload_body(file_path:, media_type:, boundary:)
      headers = {"Content-Type" => "multipart/form-data, boundary=#{boundary}"}
      client.post("media/upload?media_category=#{media_category}", upload_body, headers:)
    end

    def chunked_upload(client:, file_path:, media_category:, media_type: infer_media_type(file_path,
      media_category), boundary: SecureRandom.hex, chunk_size_mb: 1)
      validate!(file_path:, media_category:)
      media = init(client:, file_path:, media_type:, media_category:)
      chunk_size = chunk_size_mb * BYTES_PER_MB
      append(client:, file_paths: split(file_path, chunk_size), media:, media_type:, boundary:)
      client.post("media/upload?command=FINALIZE&media_id=#{media["id"]}")&.fetch("data")
    end

    def await_processing(client:, media:)
      loop do
        status = client.get("media/upload?command=STATUS&media_id=#{media["id"]}")&.fetch("data")
        return status if !status["processing_info"] || PROCESSING_INFO_STATES.include?(status["processing_info"]["state"])

        sleep status["processing_info"]["check_after_secs"].to_i
      end
    end

    private

    def validate!(file_path:, media_category:)
      raise "File not found: #{file_path}" unless File.exist?(file_path)

      return if MEDIA_CATEGORIES.include?(media_category.downcase)

      raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{MEDIA_CATEGORIES.join(", ")}"
    end

    def infer_media_type(file_path, media_category)
      case media_category.downcase
      when TWEET_GIF, DM_GIF then GIF_MIME_TYPE
      when TWEET_VIDEO, DM_VIDEO then MP4_MIME_TYPE
      when SUBTITLES then SUBRIP_MIME_TYPE
      else MIME_TYPE_MAP[File.extname(file_path).delete(".").downcase] || DEFAULT_MIME_TYPE
      end
    end

    def split(file_path, chunk_size)
      file_number = -1
      file_paths = [] # @type var file_paths: Array[String]

      File.open(file_path, "rb") do |f|
        while (chunk = f.read(chunk_size))
          path = "#{Dir.mktmpdir}/x#{format("%03d", file_number += 1)}"
          File.binwrite(path, chunk)
          file_paths << path
        end
      end
      file_paths
    end

    def init(client:, file_path:, media_type:, media_category:)
      total_bytes = File.size(file_path)
      query = "command=INIT&media_type=#{media_type}&media_category=#{media_category}&total_bytes=#{total_bytes}"
      client.post("media/upload?#{query}")&.fetch("data")
    end

    def append(client:, file_paths:, media:, media_type:, boundary: SecureRandom.hex)
      threads = file_paths.map.with_index do |file_path, index|
        Thread.new do
          upload_body = construct_upload_body(file_path:, media_type:, boundary:)
          query = "command=APPEND&media_id=#{media["id"]}&segment_index=#{index}"
          headers = {"Content-Type" => "multipart/form-data, boundary=#{boundary}"}
          upload_chunk(client:, query:, upload_body:, file_path:, headers:)
        end
      end
      threads.each(&:join)
    end

    def upload_chunk(client:, query:, upload_body:, file_path:, headers: {})
      client.post("media/upload?#{query}", upload_body, headers:)
    rescue NetworkError, ServerError
      retries ||= 0
      ((retries += 1) < MAX_RETRIES) ? retry : raise
    ensure
      cleanup_file(file_path)
    end

    def cleanup_file(file_path)
      dirname = File.dirname(file_path)
      File.delete(file_path)
      Dir.delete(dirname) if Dir.empty?(dirname)
    end

    def construct_upload_body(file_path:, media_type:, boundary: SecureRandom.hex)
      "--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"media\"; filename=\"#{File.basename(file_path)}\"\r\n" \
        "Content-Type: #{media_type}\r\n\r\n" \
        "#{File.read(file_path)}\r\n" \
        "--#{boundary}--\r\n"
    end
  end
end
