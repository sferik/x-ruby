# frozen_string_literal: true

require_relative "error"

module X
  module Uploader
    # Error raised when X fails to process uploaded media, such as a video it cannot decode
    # @api public
    class MediaProcessingFailed < Error
      # The message of a failure X gives no reason for
      DEFAULT_MESSAGE = "Media processing failed"

      # The processing status X reported, whose processing_info holds the error
      # @api public
      # @return [UploadedMedia, Hash{String => Object}] the status, which reads as a Hash
      # @example Read the error X reported
      #   error.status.dig("processing_info", "error", "name") # => "InvalidMedia"
      attr_reader :status

      # Initialize the error with the reason X gives for the failure
      #
      # @api public
      # @param status [UploadedMedia, Hash{String => Object}] the processing status X reported
      # @return [MediaProcessingFailed] a new error
      # @example Raise the error for a failed status
      #   raise X::Uploader::MediaProcessingFailed.new(status)
      def initialize(status)
        @status = status
        super(status.dig("processing_info", "error", "message") || DEFAULT_MESSAGE)
      end
    end
  end
end
