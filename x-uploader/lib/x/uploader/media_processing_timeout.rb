# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when uploaded media is still processing after the time await_processing may wait
  # @api public
  class MediaProcessingTimeout < Uploader::Error
    # The last processing status X reported, with the state and progress
    # @api public
    # @return [UploadedMedia, Hash{String => Object}, nil] the status, which reads as a Hash, or nil if none was given
    # @example Read how far processing got
    #   error.status.dig("processing_info", "progress_percent") # => 42
    attr_reader :status

    # The seconds await_processing was allowed to wait
    # @api public
    # @return [Integer, nil] the seconds, or nil if none were given
    # @example Read how long processing was awaited
    #   error.timeout # => 600
    attr_reader :timeout

    # Initialize the error with the last status and the time that was allowed
    #
    # The message is the one given, or else names the time that was allowed, when one was given.
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that names the time allowed
    # @param status [UploadedMedia, Hash{String => Object}, nil] the last processing status X reported
    # @param timeout [Integer, nil] the seconds await_processing was allowed to wait
    # @return [MediaProcessingTimeout] a new error
    # @example Raise the error after ten minutes
    #   raise X::MediaProcessingTimeout.new(status: status, timeout: 600)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::MediaProcessingTimeout, "Still processing"
    def initialize(message = nil, status: nil, timeout: nil)
      @status = status
      @timeout = timeout
      super(message || (timeout ? "Media processing did not finish within #{timeout} seconds" : "Media processing did not finish"))
    end
  end
end
