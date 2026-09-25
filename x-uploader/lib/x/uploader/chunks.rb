# frozen_string_literal: true

require_relative "json_classes"
require_relative "missing_data"
require_relative "multipart"
require_relative "utils"

module X
  module Uploader
    # Uploads a file in the chunks the X API requires for video and subtitles
    #
    # Internal to x-uploader: X::Uploader::MediaUpload calls it rather than mix its methods into itself, so a class that
    # includes X::Uploader::MediaUpload gains none of them.
    #
    # @api private
    module Chunks
      extend self

      # The message of the error raised for an initialize response that holds no media to append the chunks to
      NO_MEDIA = "The response that initializes the upload holds no media to append the chunks to"
      private_constant :NO_MEDIA

      # Initialize a chunked upload
      #
      # The chunks that follow are appended to the media this returns, so a response that holds none, whether it has
      # no body at all, a body without data, or data that names no media, raises here rather than leave the upload
      # to fail on the first chunk, once the media it uploaded had been billed.
      #
      # @api private
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param media_type [String] the MIME type
      # @param media_category [String] the media category
      # @return [Hash] the media the chunks are appended to
      # @raise [MissingData] if the response holds no media to append the chunks to
      # @example Initialize the upload of a video
      #   Uploader::Chunks.init(client:, source:, media_type: "video/mp4", media_category: "tweet_video")
      def init(client:, source:, media_type:, media_category:)
        body = {media_type:, media_category:, total_bytes: source.size}
        media = Hash.try_convert(client.post("media/upload/initialize", body, **JSON_CLASSES).to_h["data"])
        raise MissingData, NO_MEDIA unless media&.key?("id")

        media
      end

      # Append the chunks of a file to a chunked upload, a few at a time
      #
      # Each worker reads its chunk from the media as it uploads it, so no more than concurrency chunks are held
      # in memory at once. A chunk that fails stops the chunks not yet begun, and once the chunks already begun
      # have finished, the first error is raised. An exception raised in the caller while it waits, such as a
      # timeout or an interrupt, stops every chunk, so that no thread goes on uploading once the caller has gone.
      #
      # @api private
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media [Hash] the media object
      # @param boundary [String] the multipart boundary
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [void]
      # @example Append the chunks of a video
      #   Uploader::Chunks.append(client:, source:, chunk_size: 1_048_576, media:, boundary:, concurrency: 4)
      def append(client:, source:, chunk_size:, media:, boundary:, concurrency:)
        queue = chunk_queue(source, chunk_size)
        errors = Queue.new
        media_id = media.fetch("id")
        await Array.new([concurrency, queue.size].min) { append_worker(queue, errors, client:, source:, chunk_size:, media_id:, boundary:) }
        raise errors.deq unless errors.empty?
      end

      # Finalize a chunked upload, once its chunks are appended
      #
      # It is sent again after a server or network error, as a chunk is, rather than lose an upload whose every
      # chunk was appended to a failure that may pass: the media can be finalized only by the upload that
      # initialized it, which knows its identifier. A finalize the API acted on, but whose answer never arrived, may
      # be refused when it is sent again, which raises as the failure it follows would have.
      #
      # @api private
      # @param client [Client] the X API client
      # @param media [Hash] the media the chunks were appended to
      # @return [Hash, nil] the parsed response, or nil for a response that carries no body at all
      # @example Finalize the upload of a video
      #   Uploader::Chunks.finalize(client:, media: {"id" => "1880028106020515840"})
      def finalize(client:, media:)
        Utils.sending_again(client) { client.post("media/upload/#{media.fetch("id")}/finalize", **JSON_CLASSES) }
      end

      private

      # Wait for the workers to finish, stopping them if the wait is cut short
      #
      # Every worker has finished when the wait ends on its own, so there is nothing left to stop. When an exception
      # is raised in the waiting thread, the workers are killed, which closes the connection of a request under way,
      # and waited for, so that none outlives the call.
      #
      # @api private
      # @param workers [Array<Thread>] the threads that upload the chunks
      # @return [void]
      def await(workers)
        workers.each(&:join)
      ensure
        workers.each(&:kill).each(&:join)
      end

      # A closed queue of the index and byte offset of each chunk of the media, in order
      # @api private
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @return [Thread::Queue] the queue
      def chunk_queue(source, chunk_size)
        queue = Queue.new
        (0...source.size).step(chunk_size).each_with_index { |offset, index| queue << [index, offset] }
        queue.close
      end

      # Start a thread that uploads chunks from a queue, emptying it if a chunk fails
      # @api private
      # @param queue [Thread::Queue] the index and offset of each chunk not yet begun
      # @param errors [Thread::Queue] the errors of failed chunks, in the order they failed
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media_id [String] the media ID
      # @param boundary [String] the multipart boundary
      # @return [Thread] the thread
      def append_worker(queue, errors, client:, source:, chunk_size:, media_id:, boundary:)
        Thread.new do
          while (index, offset = queue.deq)
            upload_body = Multipart.body("media", source.read(chunk_size, offset), boundary:, segment_index: index)
            upload_chunk(client:, media_id:, upload_body:, headers: Multipart.headers(boundary))
          end
        rescue => e
          errors << e
          queue.clear
        end
      end

      # Upload a single chunk, sending it again after a server or network error
      #
      # A chunk names the segment it is appended at, so one sent twice is appended once, and it is sent again as
      # {Utils.sending_again} sends a request again.
      #
      # @api private
      # @param client [Client] the X API client
      # @param media_id [String] the media ID
      # @param upload_body [String] the upload body
      # @param headers [Hash] the request headers
      # @return [void]
      def upload_chunk(client:, media_id:, upload_body:, headers:)
        Utils.sending_again(client) { client.post("media/upload/#{media_id}/append", upload_body, headers:, **JSON_CLASSES) }
      end
    end
    private_constant :Chunks
  end
end
