require "x/core/errors/error"

module X
  module Uploader
    # Error raised when uploaded media is still processing after the time await_processing may wait
    # @api public
    class MediaProcessingTimeout < Error
      # The last processing status X reported, with the state and progress
      # @api public
      # @return [Hash{String => Object}] the status
      # @example Read how far processing got
      #   error.status.dig("processing_info", "progress_percent") # => 42
      attr_reader :status

      # Initialize the error with the last status and the time that was allowed
      #
      # @api public
      # @param status [Hash{String => Object}] the last processing status X reported
      # @param timeout [Integer] the seconds await_processing was allowed to wait
      # @return [MediaProcessingTimeout] a new error
      # @example Raise the error after ten minutes
      #   raise X::Uploader::MediaProcessingTimeout.new(status, 600)
      def initialize(status, timeout)
        @status = status
        super("Media processing did not finish within #{timeout} seconds")
      end
    end
  end
end
