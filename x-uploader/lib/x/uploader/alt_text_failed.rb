# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when media uploaded with alt text is uploaded, but its alt text cannot be added
  #
  # The alt text is added once the media is uploaded, and processed, so the media the upload billed is not lost to
  # a failure to add it: the error holds the media, which can be attached to a post, or given its alt text again
  # with add_alt_text. The error that failed to add it is the cause, whose message the message ends with.
  #
  # @api public
  class AltTextFailed < Uploader::Error
    # Add alt text to uploaded media, raising this error, which holds it, on failure
    #
    # Internal to x-uploader: an upload adds the alt text it is given through it.
    #
    # @api private
    # @param media [UploadedMedia] the uploaded media
    # @yield adds the alt text
    # @return [Object] what the block returns
    # @raise [AltTextFailed] if the block raises an error of the X API
    # @example Add alt text to an upload, keeping the media if it cannot be added
    #   X::AltTextFailed.keeping(media) { Uploader::Metadata.add_alt_text(media, "A cat", client:) }
    def self.keeping(media)
      yield
    rescue X::Error
      raise new(media)
    end

    # The media that was uploaded, without its alt text
    # @api public
    # @return [UploadedMedia] the uploaded media
    # @example Add the alt text again later
    #   rescue X::AltTextFailed => e
    #     client.add_alt_text(e.media, "A cat asleep on a keyboard")
    attr_reader :media

    # Initialize the error with the media that was uploaded
    #
    # @api public
    # @param media [UploadedMedia] the media that was uploaded
    # @return [AltTextFailed] a new error
    # @example Raise the error for media whose alt text could not be added
    #   raise X::AltTextFailed.new(media)
    def initialize(media)
      @media = media
      super("Media #{media.id} was uploaded, but its alt text could not be added")
    end

    # The message, ending with why the alt text could not be added
    #
    # It ends with the message of the error that failed to add the alt text, which is the cause.
    #
    # @api public
    # @return [String] the message
    # @example Read why the alt text could not be added
    #   error.message # => "Media 7 was uploaded, but its alt text could not be added: Bad Request"
    def to_s = [super, cause&.message].compact.join(": ")
  end
end
