# frozen_string_literal: true

require_relative "error"
require_relative "uploaded_media"

module X
  # Error raised when uploaded media is still processing after the time await_processing may wait
  # @api public
  class MediaProcessingTimeout < Uploader::Error
    # The message for the seconds allowed: the error is raised once the check X asks for next would come after them,
    # which is at once when X asks for the first check only after they have passed
    WITHIN_TIMEOUT = "Media processing did not finish within the %s seconds allowed: its next check would come after them"
    private_constant :WITHIN_TIMEOUT

    # The uploaded media, as the last processing status X reported describes it
    #
    # Its processing_info holds the state and progress of the processing.
    #
    # @api public
    # @return [UploadedMedia, nil] the media, which reads as a Hash, or nil if none was given
    # @example Read how far processing got
    #   error.media.dig("processing_info", "progress_percent") # => 42
    # @example Wait for the media again later
    #   rescue X::MediaProcessingTimeout => e
    #     client.await_processing(e.media)
    attr_reader :media

    # The seconds await_processing was allowed to wait
    # @api public
    # @return [Integer, Float, nil] the seconds, or nil if none were given
    # @example Read how long processing was awaited
    #   error.timeout # => 600
    attr_reader :timeout

    # Initialize the error with the last status and the time that was allowed
    #
    # The message is the one given, or else names the time that was allowed, when one was given.
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that names the time allowed
    # @param media [UploadedMedia, Hash{String => Object}, nil] the media, as the last processing status X reported
    #   describes it, a Hash of which is held as uploaded media
    # @param timeout [Integer, Float, nil] the seconds await_processing was allowed to wait
    # @return [MediaProcessingTimeout] a new error
    # @example Raise the error after ten minutes
    #   raise X::MediaProcessingTimeout.new(media: status, timeout: 600)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::MediaProcessingTimeout, "Still processing"
    def initialize(message = nil, media: nil, timeout: nil)
      @media = media.is_a?(Hash) ? UploadedMedia.new(media) : media
      @timeout = timeout
      super(message || (timeout ? format(WITHIN_TIMEOUT, timeout) : "Media processing did not finish"))
    end
  end
end
