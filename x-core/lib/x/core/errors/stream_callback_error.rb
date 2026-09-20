module X
  # Stands in for an error a callback of a stream raised, so that the connection does not take it for its own
  #
  # A stream runs the client's on_response hook, and whatever an object_class builds its objects with, inside the
  # request that reads the stream, where an IOError, a SystemCallError, or another of the errors a socket raises
  # would otherwise be reported as a NetworkError and reconnected, reading the objects the API billed again.
  #
  # Internal to x-core: StreamParser tags the errors of a callback with it, and Connection#perform_stream raises the
  # error it holds in its place.
  #
  # @api private
  class StreamCallbackError < StandardError
    # The error the callback raised
    # @api private
    # @return [StandardError] the error the callback raised
    # @example Raise the error a callback raised
    #   raise error.error
    attr_reader :error

    # Initialize a new StreamCallbackError
    #
    # It takes the message of the error it stands in for, which is read only if it escapes the connection.
    #
    # @api private
    # @param error [StandardError] the error the callback raised
    # @return [StreamCallbackError] a new instance
    # @example Tag the error a callback raised
    #   raise X::StreamCallbackError, error
    def initialize(error)
      super
      @error = error
    end
  end
end
