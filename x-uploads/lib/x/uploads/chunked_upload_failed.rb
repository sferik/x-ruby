# frozen_string_literal: true

require "timeout"
require_relative "error"
require_relative "uploaded_media"

module X
  # Error raised when a chunked upload is initialized, but its chunks cannot be appended or it cannot be finalized
  #
  # The media is created, and its identifier given, once the upload is initialized, so the media is not lost to a
  # chunk or a finalize that fails, as one the API answers with a server error, to media that can no longer be read,
  # as a file deleted, closed, or shrunk once the upload was initialized cannot, or to any other error that ends the
  # upload, as one the on_response hook of the client raises, or a thread for the chunks that cannot be started: the
  # error holds the media the upload initialized, which names it by its identifier and its media key. The error that
  # failed the upload is the cause, whose message the message ends with. A Timeout::Error, as Timeout.timeout raises
  # around the upload, is raised as it is, so that a rescue of it still catches it, unless one raised with its class,
  # as by Timeout.timeout(5, Timeout::Error), lands in the save_tokens of a refresh, which raises TokenReportFailed,
  # holding the tokens. A TokenReportFailed, which a chunk or the finalize raises when save_tokens raised for the
  # tokens of a refresh it made, is raised as it is too, rather than as this error, so that the rescue of it that
  # stores the tokens it holds catches it around an upload as around any other request.
  #
  # @api public
  class ChunkedUploadFailed < Uploads::Error
    # Finish a chunked upload, raising this error, which holds the media, on failure
    #
    # Internal to x-uploads: a chunked upload appends its chunks and finalizes the media through it, and calls it
    # with __send__, since it is private. A Timeout::Error, a TokenReportFailed, which holds the tokens of a refresh
    # that save_tokens raised for, and an exception that is not a StandardError, such as an Interrupt, are raised as
    # they are. The error holds the identifier and media key of the media alone, since the
    # rest of the response that initialized the upload, such as its expires_after_secs, says nothing of whether the
    # media can be attached to a post, so that its ready? is false and await_media_processing checks it.
    #
    # @api private
    # @param media [Hash{String => Object}] the media the upload initialized
    # @yield appends the chunks and finalizes the upload
    # @return [Object] what the block returns
    # @raise [ChunkedUploadFailed] if the block raises a StandardError other than a Timeout::Error or a
    #   TokenReportFailed, such as an error of the X API, or one of reading the media, as a file deleted, closed, or
    #   shrunk once the upload was initialized raises
    # @raise [TokenReportFailed] if save_tokens raises for the tokens of a refresh the block made, with the tokens
    # @example Finish a chunked upload, keeping the media if it fails
    #   X::ChunkedUploadFailed.__send__(:keeping, media) { Uploads::Chunks.finalize(client:, media:) }
    def self.keeping(media)
      yield
    rescue Timeout::Error, TokenReportFailed
      raise
    rescue
      raise new(media: media.slice("id", "media_key"))
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
