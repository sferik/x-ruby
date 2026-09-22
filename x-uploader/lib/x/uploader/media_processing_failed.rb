# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when X fails to process uploaded media, such as a video it cannot decode
  # @api public
  class MediaProcessingFailed < Uploader::Error
    # The message of a failure X gives no reason for
    DEFAULT_MESSAGE = "Media processing failed"
    private_constant :DEFAULT_MESSAGE

    # The processing status X reported, whose processing_info holds the error
    # @api public
    # @return [UploadedMedia, Hash{String => Object}, nil] the status, which reads as a Hash, or nil if none was given
    # @example Read the error X reported
    #   error.status.dig("processing_info", "error", "name") # => "InvalidMedia"
    attr_reader :status

    # Initialize the error with the reason X gives for the failure
    #
    # The message is the one given, or else the reason the status holds, or else "Media processing failed".
    #
    # @api public
    # @param message [String, nil] the message, or nil for the reason the status holds
    # @param status [UploadedMedia, Hash{String => Object}, nil] the processing status X reported
    # @return [MediaProcessingFailed] a new error
    # @example Raise the error for a failed status
    #   raise X::MediaProcessingFailed.new(status: status)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::MediaProcessingFailed, "Unsupported video format"
    def initialize(message = nil, status: nil)
      @status = status
      super(message || status&.dig("processing_info", "error", "message") || DEFAULT_MESSAGE)
    end
  end
end
