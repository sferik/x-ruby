# frozen_string_literal: true

require "x/core/retry_handler"
require_relative "media_processing_failed"
require_relative "missing_media_data"
require_relative "uploaded_media"

module X
  module Uploader
    # Helpers shared across the uploaders
    #
    # Internal to x-uploader: the uploaders call it rather than mix its methods into themselves, so a class that
    # includes an uploader gains none of them.
    #
    # @api private
    module Utils
      extend self

      # The media categories the subtitles endpoint takes, by the category the video was uploaded as
      SUBTITLED_MEDIA_CATEGORIES = {"tweet_video" => "TweetVideo", "amplify_video" => "AmplifyVideo"}.freeze
      # The message of the error raised for media that holds no identifier
      NO_MEDIA_ID = "The media given holds no identifier"
      # The message of the error raised for a response of an upload that holds no media
      NO_MEDIA = "The response %s holds no media"
      # The message of the error raised for something that is neither media nor the identifier of media
      NOT_MEDIA = "%s is not media: pass uploaded media, the Hash of an upload response, or a media identifier"
      private_constant :NO_MEDIA_ID, :NO_MEDIA, :NOT_MEDIA

      # The lowercase extension of a file, without its dot
      #
      # @api private
      # @param file_path [String, Pathname] the path to the file
      # @return [String] the extension
      # @example The extension of a file
      #   Uploader::Utils.extension("cat.JPG") # => "jpg"
      def extension(file_path) = File.extname(file_path).delete(".").downcase

      # The media identifier of an upload response or of an identifier
      #
      # Nil, or an empty identifier, names no media, and would reach the API as an identifier that is not there.
      # Anything else raises rather than reach the API as whatever its to_s reads, such as the inspection of an
      # object.
      #
      # @api private
      # @param media [UploadedMedia, Hash, String, Integer] the uploaded media, the upload response, or the media
      #   identifier
      # @return [String] the media identifier
      # @raise [ArgumentError] if the media is neither media nor a media identifier
      # @raise [MissingMediaData] if the media is nil or empty, or an upload response holds no identifier
      # @example The identifier of uploaded media
      #   Uploader::Utils.media_id({"id" => "1880028106020515840"}) # => "1880028106020515840"
      def media_id(media)
        id = case media
        when Hash, UploadedMedia then media.fetch("id", nil)
        when String, Integer, nil then media
        else raise ArgumentError, format(NOT_MEDIA, media.inspect)
        end
        id.to_s.then { |text| text.empty? ? raise(MissingMediaData, NO_MEDIA_ID) : text }
      end

      # The media a response of an upload describes
      #
      # The API answers an upload with what it acted on, under the data of the response.
      # A response that succeeded without it describes no media, whether it carries no body at all or a body without
      # data, so it raises rather than leave the upload to fail later on what is missing, or return nothing for media
      # the API may have billed.
      #
      # @api private
      # @param response [Hash, nil] the parsed response body, or nil for a response without one
      # @param description [String] how the error names the response, for its message
      # @return [Hash] the media
      # @raise [MissingMediaData] if the response holds no media
      # @example The media an upload returned
      #   Uploader::Utils.media_data({"data" => {"id" => 7}}, "of the upload") # => {"id" => 7}
      def media_data(response, description)
        Hash.try_convert(response.to_h["data"]) || raise(MissingMediaData, format(NO_MEDIA, description))
      end

      # Send a request again after a server or network error, as an idempotent one is
      #
      # A client sends no POST again, since the API may have acted on one whose answer never arrived, but some of
      # the POSTs of an upload have the same effect sent twice as sent once, such as a chunk, which names the segment
      # it is appended at. Those are sent again up to the max_retries of the client, after the wait a failed response
      # asks for, or a backoff that grows with each retry and is cut short at random, so that the requests one
      # failure ended are not sent again together.
      #
      # @api private
      # @param client [Client] the X API client
      # @yield sends the request
      # @return [Object] what the block returns
      # @example Append a chunk, again after a failure
      #   Uploader::Utils.sending_again(client) { client.post("media/upload/1/append", body, headers:) }
      def sending_again(client, &)
        Core::RetryHandler.new(max_retries: max_retries_of(client)).handle(idempotent: true, &)
      end

      # The number of times a request of an upload is sent again
      #
      # It is the max_retries of a client that has one, as X::Client does, and the default of a client otherwise.
      #
      # @api private
      # @param client [Client] the X API client
      # @return [Integer] the maximum number of retries
      # @example The retries of a client
      #   Uploader::Utils.max_retries_of(X::Client.new(max_retries: 5)) # => 5
      def max_retries_of(client)
        retrying = client #: untyped
        retrying.respond_to?(:max_retries) ? retrying.max_retries : Core::RetryHandler::DEFAULT_MAX_RETRIES
      end

      # The processing status of media, unless the media failed to process
      #
      # @api private
      # @param status [UploadedMedia] the processing status X reported, or the response of an upload
      # @return [UploadedMedia] the status, of media that has processed, is still processing, or needs no processing
      # @raise [MediaProcessingFailed] if the media failed to process, with the status
      # @example The status of media that has processed
      #   Uploader::Utils.processed!(status) # => status
      def processed!(status) = status.tap { raise MediaProcessingFailed.new(status:) if status.failed? }

      # The time on the monotonic clock some seconds from now, which keeps a deadline
      #
      # The monotonic clock counts from no time in particular, but never goes back, as the time of day does when the
      # clock of the system is set, so the seconds between two of its times are the seconds that passed between them.
      #
      # @api private
      # @param seconds [Integer, Float] the seconds from now, or Float::INFINITY for a time never reached
      # @return [Float] the time on the monotonic clock
      # @example The time on the monotonic clock a minute from now
      #   Uploader::Utils.seconds_from_now(60) # => 1234.5
      def seconds_from_now(seconds) = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

      # The media category the subtitles endpoint takes, from one given in any form
      #
      # The uploaders take a category as tweet_video, in any case, and the endpoint names it TweetVideo, so both are
      # taken, and any other category raises before a request the endpoint would refuse.
      #
      # @api private
      # @param media_category [String, Symbol] the media category, in any form
      # @return [String] the media category as the subtitles endpoint names it
      # @raise [ArgumentError] if the media category is neither tweet_video nor amplify_video
      # @example The category of subtitles for a video attached to a post
      #   Uploader::Utils.subtitled_media_category(:tweet_video) # => "TweetVideo"
      def subtitled_media_category(media_category)
        key = media_category.to_s.sub(/([a-z])([A-Z])/, '\1_\2').downcase
        SUBTITLED_MEDIA_CATEGORIES.fetch(key) do
          raise ArgumentError, "Invalid media_category: #{media_category}. Valid values: #{SUBTITLED_MEDIA_CATEGORIES.keys.join(", ")}"
        end
      end
    end
    private_constant :Utils
  end
end
