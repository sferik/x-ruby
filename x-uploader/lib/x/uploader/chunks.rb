require_relative "json_classes"

module X
  module Uploader
    # Uploads a file in the chunks the X API requires for video and subtitles
    # @api private
    module Chunks
      # Maximum number of retry attempts for failed uploads
      MAX_RETRIES = 3
      # Default number of chunks uploaded at once
      DEFAULT_CONCURRENCY = 4
      # Seconds to wait before retrying a chunk, doubled for each retry after
      RETRY_BACKOFF = 1

      private

      # Initialize a chunked upload
      # @api private
      # @param client [Client] the X API client
      # @param file_path [String] the file path
      # @param media_type [String] the MIME type
      # @param media_category [String] the media category
      # @return [Hash, nil] the initialization response
      def init(client:, file_path:, media_type:, media_category:)
        body = {media_type:, media_category:, total_bytes: File.size(file_path)}
        client.post("media/upload/initialize", body, **JSON_CLASSES)&.fetch("data")
      end

      # Append the chunks of a file to a chunked upload, a few at a time
      #
      # Each worker reads its chunk from the file as it uploads it, so no more than concurrency chunks are held
      # in memory at once. A chunk that fails stops the chunks not yet begun, and once the chunks already begun
      # have finished, the first error is raised.
      #
      # @api private
      # @param client [Client] the X API client
      # @param file_path [String] the file path
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media [Hash] the media object
      # @param boundary [String] the multipart boundary
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [void]
      def append(client:, file_path:, chunk_size:, media:, boundary:, concurrency: DEFAULT_CONCURRENCY)
        queue = chunk_queue(file_path, chunk_size)
        errors = Queue.new
        media_id = media.fetch("id")
        Array.new([concurrency, queue.size].min) { append_worker(queue, errors, client:, file_path:, chunk_size:, media_id:, boundary:) }.each(&:join)
        raise errors.deq unless errors.empty?
      end

      # A closed queue of the index and byte offset of each chunk of a file, in order
      # @api private
      # @param file_path [String] the file path
      # @param chunk_size [Integer] the chunk size in bytes
      # @return [Thread::Queue] the queue
      def chunk_queue(file_path, chunk_size)
        queue = Queue.new
        (0...File.size(file_path)).step(chunk_size).each_with_index { |offset, index| queue << [index, offset] }
        queue.close
      end

      # Start a thread that uploads chunks from a queue, emptying it if a chunk fails
      # @api private
      # @param queue [Thread::Queue] the index and offset of each chunk not yet begun
      # @param errors [Thread::Queue] the errors of failed chunks, in the order they failed
      # @param client [Client] the X API client
      # @param file_path [String] the file path
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media_id [String] the media ID
      # @param boundary [String] the multipart boundary
      # @return [Thread] the thread
      def append_worker(queue, errors, client:, file_path:, chunk_size:, media_id:, boundary:)
        Thread.new do
          while (index, offset = queue.deq)
            upload_body = construct_upload_body(content: File.binread(file_path, chunk_size, offset), segment_index: index, boundary:)
            upload_chunk(client:, media_id:, upload_body:, headers: {"Content-Type" => "multipart/form-data; boundary=#{boundary}"})
          end
        rescue => e
          errors << e
          queue.clear
        end
      end

      # Upload a single chunk, retrying a server or network error after a growing wait
      # @api private
      # @param client [Client] the X API client
      # @param media_id [String] the media ID
      # @param upload_body [String] the upload body
      # @param headers [Hash] the request headers
      # @return [void]
      def upload_chunk(client:, media_id:, upload_body:, headers:)
        retries = 0
        begin
          client.post("media/upload/#{media_id}/append", upload_body, headers:, **JSON_CLASSES)
        rescue NetworkError, ServerError
          raise unless (retries += 1) < MAX_RETRIES

          sleep RETRY_BACKOFF << (retries - 1)
          retry
        end
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
