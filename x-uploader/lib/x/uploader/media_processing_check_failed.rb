# frozen_string_literal: true

require_relative "error"
require_relative "media_processing_timeout"

module X
  # Error raised when media is uploaded, but a check of its processing fails
  #
  # An upload awaits the processing of media X processes, such as a video, once the media is uploaded, and billed,
  # so the media is not lost to a check that fails, as one the API answers with a server error: the error holds the
  # media, which can be awaited again with await_processing. The error that failed the check is the cause, whose
  # message the message ends with.
  #
  # @api public
  class MediaProcessingCheckFailed < Uploader::Error
    # Await processing, raising this error, which holds the media, if a check fails
    #
    # Internal to x-uploader: an upload awaits the processing of the media it uploaded through it, and calls it with
    # __send__, since it is private. A MediaProcessingTimeout, which holds the media itself, is raised as it is.
    #
    # @api private
    # @param media [UploadedMedia] the uploaded media
    # @yield awaits the processing
    # @return [Object] what the block returns
    # @raise [MediaProcessingCheckFailed] if the block raises an error of the X API other than MediaProcessingTimeout
    # @raise [MediaProcessingTimeout] if the media is still processing once the processing timeout would pass
    # @example Await the processing of an upload, keeping the media if a check fails
    #   X::MediaProcessingCheckFailed.__send__(:keeping, media) { Uploader::MediaUpload.await_processing(media, client:) }
    def self.keeping(media)
      yield
    rescue MediaProcessingTimeout
      raise
    rescue X::Error
      raise new(media:)
    end
    private_class_method :keeping

    # The media that was uploaded, as the upload response describes it
    # @api public
    # @return [UploadedMedia, nil] the uploaded media, or nil if none was given
    # @example Await the processing of the media again later
    #   rescue X::MediaProcessingCheckFailed => e
    #     client.await_processing(e.media)
    attr_reader :media

    # Initialize the error with the media that was uploaded
    #
    # The message is the one given, or else names the media by its identifier, when media was given.
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that names the media
    # @param media [UploadedMedia, nil] the media that was uploaded
    # @return [MediaProcessingCheckFailed] a new error
    # @example Raise the error for media whose processing could not be checked
    #   raise X::MediaProcessingCheckFailed.new(media: media)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::MediaProcessingCheckFailed, "Processing could not be checked"
    def initialize(message = nil, media: nil)
      @media = media
      super(message || ["Media", media&.id, "was uploaded, but its processing could not be checked"].compact.join(" "))
    end

    # The message, ending with why the processing could not be checked
    #
    # It ends with the message of the error that failed the check, which is the cause, if there is one, whether the
    # message was given or named the media.
    #
    # @api public
    # @return [String] the message
    # @example Read why the processing could not be checked
    #   error.message # => "Media 7 was uploaded, but its processing could not be checked: Service Unavailable"
    def to_s = [super, cause&.message].compact.join(": ")
  end
end
