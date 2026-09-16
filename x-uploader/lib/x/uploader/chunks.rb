require "tmpdir"

module X
  module Uploader
    # Uploads a file in the chunks the X API requires for video and subtitles
    # @api private
    module Chunks
      # Maximum number of retry attempts for failed uploads
      MAX_RETRIES = 3

      private

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
            Thread.current.report_on_exception = false
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
