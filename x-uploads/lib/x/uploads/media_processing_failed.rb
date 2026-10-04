# frozen_string_literal: true

require_relative "error"
require_relative "uploaded_media"

module X
  # Error raised when X fails to process uploaded media, such as a video it cannot decode
  # @api public
  class MediaProcessingFailed < Uploads::Error
    # The message of a failure X gives no reason for
    DEFAULT_MESSAGE = "Media processing failed"
    private_constant :DEFAULT_MESSAGE

    # The uploaded media, as the processing status X reported describes it
    #
    # Its processing_info holds the state X reported, and the error, when X reported one.
    #
    # @api public
    # @return [UploadedMedia, nil] the media, which reads as a Hash, or nil if none was given
    # @example Read the state X reported
    #   error.media.state # => "failed"
    attr_reader :media

    # Initialize the error with the reason X gives for the failure
    #
    # The message is the one given, or else the reason the processing status holds, or else "Media processing
    # failed".
    #
    # @api public
    # @param message [String, nil] the message, or nil for the reason the processing status holds
    # @param media [UploadedMedia, Hash{String => Object}, nil] the media, as the processing status X reported
    #   describes it, a Hash of which is held as uploaded media
    # @return [MediaProcessingFailed] a new error
    # @example Raise the error for a failed status
    #   raise X::MediaProcessingFailed.new(media: status)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::MediaProcessingFailed, "Unsupported video format"
    def initialize(message = nil, media: nil)
      @media = media.is_a?(Hash) ? UploadedMedia.new(media) : media
      super(message || media&.dig("processing_info", "error", "message") || DEFAULT_MESSAGE)
    end
  end
end
