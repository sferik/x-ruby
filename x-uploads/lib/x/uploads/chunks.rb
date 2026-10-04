# frozen_string_literal: true

require "securerandom"
require_relative "chunked_upload_failed"
require_relative "json_classes"
require_relative "missing_media_data"
require_relative "multipart"
require_relative "uploaded_media"
require_relative "utils"
require_relative "validator"

module X
  module Uploads
    # Uploads a file in the chunks the X API requires for video and subtitles
    #
    # Internal to x-uploads: X::Uploads::MediaUpload calls it rather than mix its methods into itself, so a class that
    # includes X::Uploads::MediaUpload gains none of them.
    #
    # @api private
    module Chunks
      extend self

      # The message of the error raised for an initialize response that holds no media to append the chunks to
      NO_MEDIA = "The response that initializes the upload holds no media to append the chunks to"
      # The message of the error raised for a chunk that reads fewer bytes than the media held when it was measured
      CHANGED = "%s held %d bytes when the upload was initialized, but chunk %d read %d of the %d it began with at " \
        "byte %d: the media changed while it was uploaded"
      # The fiber-local key x-core reads the guard it runs the save_tokens of a refresh inside from
      REPORT_GUARD = :x_core_refresh_report_guard
      private_constant :NO_MEDIA, :CHANGED, :REPORT_GUARD

      # Raised in a worker to stop it, which the worker rescues to end at once
      #
      # It is not a StandardError, as Timeout::ExitException is not, so that a callback the client runs in the worker,
      # as an on_response or a load_tokens that rescues the errors of its own store, cannot rescue it and let the upload
      # go on after the call has ended, as Thread#kill, which cannot be rescued, did not.
      class Stopped < Exception; end # rubocop:disable Lint/InheritException
      private_constant :Stopped

      # Upload media in chunks: initialize, append each chunk, and finalize
      #
      # MediaUpload.upload and MediaUpload.chunked_upload both upload with it, once each has checked its other
      # arguments, so that upload calls no method a class that includes MediaUpload could define in place of its own.
      # The chunk size is checked against the segments the API numbers before the upload is initialized.
      #
      # @api private
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param media_type [String] the MIME type
      # @param media_category [String] the media category
      # @param chunk_size [Integer, nil] the chunk size in bytes, or nil for one derived from the size of the media
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @param shared [Boolean, nil] whether the media is shared, or nil to send none
      # @param additional_owners [Array<Integer, String>, nil] the identifiers of the users who may use the media, or
      #   nil for none
      # @return [UploadedMedia] the uploaded media, as the response that finalizes the upload describes it
      # @raise [ArgumentError] if the chunk size would need more segments than the API numbers
      # @raise [MissingMediaData] if the response that initializes the upload holds no media to append the chunks to
      # @raise [ChunkedUploadFailed] if the upload is initialized, but a chunk cannot be appended, or it cannot be
      #   finalized, or the response that finalizes it holds no media, with the media it initialized
      # @example Upload a video in chunks
      #   Uploads::Chunks.upload(client:, source:, media_type: "video/mp4", media_category: "tweet_video",
      #     chunk_size: 4_194_304, concurrency: 4)
      def upload(client:, source:, media_type:, media_category:, chunk_size:, concurrency:, shared:, additional_owners:)
        chunk_size = Validator.validate_segments!(source, chunk_size)
        media = init(client:, source:, media_type:, media_category:, shared:, additional_owners:)
        ChunkedUploadFailed.__send__(:keeping, media) { complete(client:, source:, chunk_size:, media:, concurrency:) }
      end

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
      # @param shared [Boolean, nil] whether the media is shared, or nil to send none
      # @param additional_owners [Array<Integer, String>, nil] the identifiers of the users who may use the media, or
      #   nil for none
      # @return [Hash] the media the chunks are appended to
      # @raise [MissingMediaData] if the response holds no media to append the chunks to
      # @example Initialize the upload of a video
      #   Uploads::Chunks.init(client:, source:, media_type: "video/mp4", media_category: "tweet_video")
      def init(client:, source:, media_type:, media_category:, shared: nil, additional_owners: nil)
        body = {media_type:, media_category:, total_bytes: source.size, shared:, additional_owners: additional_owners&.map(&:to_s)}.compact
        response = client.post("media/upload/initialize", body, **JSON_CLASSES)
        body = Utils.body_of(response)
        media = body["data"]
        raise MissingMediaData.new(NO_MEDIA, problems: Problem.all_from(body)) unless UploadedMedia.__send__(:documented?, media)

        media
      end

      # Append the chunks of a file to a chunked upload, a few at a time
      #
      # Each worker reads its chunk from the media as it uploads it, so no more than concurrency chunks are held
      # in memory at once. A chunk that fails stops the chunks not yet begun, and once the chunks already begun
      # have finished, the first error is raised, unless save_tokens raised for the tokens of a refresh a chunk made,
      # whose TokenReportFailed is raised in its place, whichever chunk failed first, since no other error holds the
      # tokens. An exception raised in the caller while it waits, such as a timeout or an interrupt, stops every
      # chunk, so that no thread goes on uploading once the caller has gone.
      #
      # @api private
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media [Hash] the media object
      # @param boundary [String] the multipart boundary
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [void]
      # @raise [TokenReportFailed] if save_tokens raises for the tokens of a refresh a chunk made, with the tokens
      # @raise [StandardError] if a chunk fails otherwise, the error of the first that failed
      # @example Append the chunks of a video
      #   Uploads::Chunks.append(client:, source:, chunk_size: 4_194_304, media:, boundary:, concurrency: 4)
      def append(client:, source:, chunk_size:, media:, boundary:, concurrency:)
        queue = chunk_queue(source, chunk_size)
        errors = Queue.new
        media_id = media.fetch("id")
        await([concurrency, queue.size].min, queue) { append_worker(queue, errors, client:, source:, chunk_size:, media_id:, boundary:) }
        error = failure(errors)
        raise error if error
      end

      # Append the chunks of a file to a chunked upload and finalize it
      #
      # @api private
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media [Hash] the media the upload initialized
      # @param concurrency [Integer] the number of chunks uploaded at once
      # @return [UploadedMedia] the uploaded media, as the response that finalizes the upload describes it
      # @raise [MissingMediaData] if the response that finalizes the upload holds no media or carries no body at all
      # @example Upload the chunks of a video and finalize it
      #   Uploads::Chunks.complete(client:, source:, chunk_size: 4_194_304, media:, concurrency: 4)
      def complete(client:, source:, chunk_size:, media:, concurrency:)
        append(client:, source:, chunk_size:, media:, boundary: SecureRandom.hex, concurrency:)
        UploadedMedia.new(Utils.media_data(finalize(client:, media:), "that finalizes the upload"))
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
      #   Uploads::Chunks.finalize(client:, media: {"id" => "1880028106020515840"})
      def finalize(client:, media:)
        Utils.sending_again(client) { client.post("media/upload/#{media.fetch("id")}/finalize", **JSON_CLASSES) }
      end

      private

      # Start the workers and wait for them, stopping them if the wait is cut short
      #
      # Every worker has finished when the wait ends on its own, so there is nothing left to stop. When an exception is
      # raised in the waiting thread, the workers are stopped, which closes the connection of a request under way, and
      # waited for, so that none outlives the call. A worker that is storing the tokens of a refresh it made finishes
      # first, so that its save_tokens is not cut short, leaving the store with a refresh token X no longer accepts,
      # while a timeout of its own still ends it. The workers are started inside the wait, so that one that cannot be
      # started, as a thread the system refuses raises ThreadError, or an exception raised in the caller while they are
      # started, stops those started before it as well.
      #
      # Each worker is started, and the workers are stopped, holding back an exception raised in the caller, which
      # would otherwise leave a worker it struck as it was started, or as the others were stopped, uploading every
      # chunk left. An exception a trap raises is not held back, so the chunks not yet begun are emptied first, and a
      # worker it leaves unstopped ends once the chunk it began is uploaded. A worker reading a chunk from the media
      # finishes reading it first, so that the file it reads is closed.
      #
      # @api private
      # @param count [Integer] the number of workers to start
      # @param queue [Thread::Queue] the index and offset of each chunk not yet begun
      # @yieldreturn [Thread] a worker it started, a thread that uploads chunks
      # @return [void]
      def await(count, queue)
        workers = [] #: Array[Thread]
        begin
          count.times { Thread.handle_interrupt(Object => :never) { workers << yield } }
          workers.each(&:join)
        ensure
          Thread.handle_interrupt(Object => :never) { stop(workers, queue) }
          workers.each(&:join)
        end
      end

      # Empty the chunks not yet begun, then stop the workers
      # @api private
      # @param workers [Array<Thread>] the workers
      # @param queue [Thread::Queue] the index and offset of each chunk not yet begun
      # @return [void]
      def stop(workers, queue)
        queue.clear
        workers.each { |worker| worker.raise(Stopped) }
      end

      # The error the chunks that failed raise, of those they recorded
      #
      # It is that of the first chunk that failed, unless save_tokens raised for the tokens of a refresh a chunk made:
      # a TokenReportFailed is raised in place of any other error, since it alone holds tokens the store has yet to
      # hold, and the last of them, if more than one refresh was made, since the refresh token of an earlier one is
      # spent.
      #
      # @api private
      # @param errors [Thread::Queue] the errors of failed chunks, in the order they failed
      # @return [StandardError, nil] the error to raise, or nil if no chunk failed
      def failure(errors)
        failures = Array.new(errors.size) { errors.deq }
        failures.reverse_each.find { |error| TokenReportFailed === error } || failures.first
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
      #
      # The thread is started holding every exception back, as a new thread holds back what the thread that starts it
      # does, and takes them once it runs where it rescues Stopped, so that one stopped before it begins ends there
      # rather than with Stopped, and a timeout of its own save_tokens still ends it.
      #
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
          Thread.handle_interrupt(Object => :immediate) { append_chunks(queue, errors, client:, source:, chunk_size:, media_id:, boundary:) }
        rescue Stopped
          # A worker stopped before or between its requests ends as one stopped mid-request does
        end
      end

      # Upload chunks from a queue until it is empty, emptying it if a chunk fails
      # @api private
      # @param queue [Thread::Queue] the index and offset of each chunk not yet begun
      # @param errors [Thread::Queue] the errors of failed chunks, in the order they failed
      # @param client [Client] the X API client
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param media_id [String] the media ID
      # @param boundary [String] the multipart boundary
      # @return [void]
      def append_chunks(queue, errors, client:, source:, chunk_size:, media_id:, boundary:)
        Thread.current[REPORT_GUARD] = method(:saving)
        while (index, offset = queue.deq)
          upload_body = Multipart.body("media", chunk(source, chunk_size, index, offset), boundary:, segment_index: index)
          upload_chunk(client:, media_id:, upload_body:, headers: Multipart.headers(boundary))
        end
      rescue => e
        errors << e
        queue.clear
      end

      # Run the save_tokens of a worker, holding a stop back until it returns
      # @api private
      # @yield passes the tokens of the refresh to save_tokens
      # @return [Object] what the block returns
      def saving(&) = Thread.handle_interrupt(Stopped => :never, &)

      # Read a chunk of the media, of the bytes the upload declared it holds
      #
      # The size of the media is read once, so every chunk is read within the bytes the upload was initialized with,
      # and a file that grows while it is uploaded appends none of what it grew by. A file that shrinks cannot fill
      # the chunks it was measured for, so a chunk that reads short raises, rather than append fewer bytes than the
      # upload declared.
      #
      # A stop of the worker is held back until the chunk is read. Ruby raises an exception raised in a thread once
      # the file is opened, before anything holds the handle to close it, so a worker stopped as it opened the file
      # would leave it open for as long as the process ran, and a file left open cannot be deleted on Windows.
      #
      # @api private
      # @param source [Source] the media
      # @param chunk_size [Integer] the chunk size in bytes
      # @param index [Integer] the index of the chunk
      # @param offset [Integer] the byte the chunk begins at
      # @return [String] the bytes of the chunk
      # @raise [EOFError] if the media holds fewer bytes than it did when it was measured
      def chunk(source, chunk_size, index, offset)
        length = [chunk_size, source.size - offset].min
        bytes = Thread.handle_interrupt(Stopped => :never) { source.read(length, offset) }.to_s
        return bytes if bytes.bytesize.eql?(length)

        raise EOFError, format(CHANGED, source.description, source.size, index, bytes.bytesize, length, offset)
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
