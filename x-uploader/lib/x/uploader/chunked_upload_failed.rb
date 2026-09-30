# frozen_string_literal: true

require_relative "error"
require_relative "uploaded_media"

module X
  # Error raised when a chunked upload is initialized, but its chunks cannot be appended or it cannot be finalized
  #
  # The media is created, and its identifier given, once the upload is initialized, so the media is not lost to a
  # chunk or a finalize that fails, as one the API answers with a server error: the error holds the media the upload
  # initialized, which names it by its identifier and its media key. The error that failed the upload is the cause,
  # whose message the message ends with.
  #
  # @api public
  class ChunkedUploadFailed < Uploader::Error
    # Finish a chunked upload, raising this error, which holds the media, on failure
    #
    # Internal to x-uploader: a chunked upload appends its chunks and finalizes the media through it, and calls it
    # with __send__, since it is private.
    #
    # @api private
    # @param media [Hash{String => Object}] the media the upload initialized
    # @yield appends the chunks and finalizes the upload
    # @return [Object] what the block returns
    # @raise [ChunkedUploadFailed] if the block raises an error of the X API
    # @example Finish a chunked upload, keeping the media if it fails
    #   X::ChunkedUploadFailed.__send__(:keeping, media) { Uploader::Chunks.finalize(client:, media:) }
    def self.keeping(media)
      yield
    rescue X::Error
      raise new(media:)
    end
    private_class_method :keeping

    # The media the upload initialized, which names it by its identifier
    # @api public
    # @return [UploadedMedia, nil] the media, or nil if none was given
    # @example Read the identifier of the media an upload left unfinished
    #   rescue X::ChunkedUploadFailed => e
    #     e.media.id # => 1880028106020515840
    attr_reader :media

    # Initialize the error with the media the upload initialized
    #
    # The message is the one given, or else names the media by its identifier, when media that holds one was given.
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that names the media
    # @param media [UploadedMedia, Hash{String => Object}, nil] the media the upload initialized, a Hash of which is
    #   held as uploaded media
    # @return [ChunkedUploadFailed] a new error
    # @example Raise the error for media whose upload could not be finished
    #   raise X::ChunkedUploadFailed.new(media: media)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::ChunkedUploadFailed, "The upload could not be finished"
    def initialize(message = nil, media: nil)
      @media = media.is_a?(Hash) ? UploadedMedia.new(media) : media
      super(message || ["Media", media&.[]("id"), "was initialized, but its upload could not be finished"].compact.join(" "))
    end

    # The message, ending with why the upload could not be finished
    #
    # It ends with the message of the error that failed the upload, which is the cause, if there is one, whether the
    # message was given or named the media.
    #
    # @api public
    # @return [String] the message
    # @example Read why the upload could not be finished
    #   error.message # => "Media 7 was initialized, but its upload could not be finished: Service Unavailable"
    def to_s = [super, cause&.message].compact.join(": ")
  end
end
