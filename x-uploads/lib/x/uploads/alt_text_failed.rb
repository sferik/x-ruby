# frozen_string_literal: true

require "timeout"
require_relative "error"
require_relative "uploaded_media"

module X
  # Error raised when media uploaded with alt text is uploaded, but its alt text cannot be added
  #
  # The alt text is added once the media is uploaded, and processed, so the media uploaded is not lost to
  # a failure to add it, whether the API refuses it or the on_response hook of the client raises: the error holds the
  # media, which can be attached to a post, or given its alt text again with add_alt_text. The error that failed to
  # add it is the cause, whose message the message ends with. A TokenReportFailed, which the request raises when
  # save_tokens raised for the tokens of a refresh it made, is raised as it is, rather than as this error, so that the
  # rescue of it that stores the tokens it holds catches it around an upload as around any other request.
  #
  # @api public
  class AltTextFailed < Uploads::Error
    # Add alt text to uploaded media, raising this error, which holds it, on failure
    #
    # Internal to x-uploads: an upload adds the alt text it is given through it, and calls it with __send__, since it
    # is private. A Timeout::Error, as Timeout.timeout raises around the upload, a TokenReportFailed, which holds the
    # tokens of a refresh that save_tokens raised for, and an exception that is not a StandardError, such as an
    # Interrupt, are raised as they are.
    #
    # @api private
    # @param media [UploadedMedia] the uploaded media
    # @yield adds the alt text
    # @return [Object] what the block returns
    # @raise [AltTextFailed] if the block raises a StandardError other than a Timeout::Error or a TokenReportFailed,
    #   such as an error of the X API
    # @raise [TokenReportFailed] if save_tokens raises for the tokens of a refresh the block made, with the tokens
    # @example Add alt text to an upload, keeping the media if it cannot be added
    #   X::AltTextFailed.__send__(:keeping, media) { Uploads::Metadata.add_alt_text(media, "A cat", client:) }
    def self.keeping(media)
      yield
    rescue Timeout::Error, TokenReportFailed
      raise
    rescue
      raise new(media:)
    end
    private_class_method :keeping

    # The media that was uploaded, without its alt text
    # @api public
    # @return [UploadedMedia, nil] the uploaded media, or nil if none was given
    # @example Add the alt text again later
    #   rescue X::AltTextFailed => e
    #     client.add_alt_text(e.media, "A cat asleep on a keyboard")
    attr_reader :media

    # Initialize the error with the media that was uploaded
    #
    # The message is the one given, or else names the media by its identifier, when media that holds one was given.
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that names the media
    # @param media [UploadedMedia, Hash{String => Object}, nil] the media that was uploaded, a Hash of which is held as
    #   uploaded media
    # @return [AltTextFailed] a new error
    # @example Raise the error for media whose alt text could not be added
    #   raise X::AltTextFailed.new(media: media)
    # @example Raise the error with a message of its own, as a test stub may
    #   raise X::AltTextFailed, "Alt text could not be added"
    def initialize(message = nil, media: nil)
      @media = media.is_a?(Hash) ? UploadedMedia.new(media) : media
      super(message || ["Media", media&.[]("id"), "was uploaded, but its alt text could not be added"].compact.join(" "))
    end

    # The message, ending with why the alt text could not be added
    #
    # It ends with the message of the error that failed to add the alt text, which is the cause, if there is one,
    # whether the message was given or named the media.
    #
    # @api public
    # @return [String] the message
    # @example Read why the alt text could not be added
    #   error.message # => "Media 7 was uploaded, but its alt text could not be added: Bad Request"
    def to_s = [super, cause&.message].compact.join(": ")
  end
end
