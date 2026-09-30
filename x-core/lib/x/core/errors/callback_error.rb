# frozen_string_literal: true

module X
  module Core
    # Stands in for an error a callback raised, so that what runs it does not take it for an error of its own
    #
    # A request runs the client's on_response hook, the block it was passed, and whatever an object_class builds its
    # objects with, inside the handlers that send it again, wait out a rate limit, and refresh a rejected token, where
    # an X::ServerError, an X::TooManyRequests, or an X::Unauthorized a callback raised, such as one of a request it
    # made itself, would otherwise send the request again, reading what the API billed again, or spend a refresh
    # token. A stream runs its callbacks inside the request that reads it, where an IOError, a SystemCallError, or
    # another of the errors a socket raises would otherwise be reported as a NetworkError and reconnected.
    #
    # Internal to x-core: Client#perform, ResponseParser, and StreamParser tag the errors of a callback with it, and
    # Client and Connection#perform_stream raise the error it holds in its place.
    #
    # @api private
    class CallbackError < StandardError
      # The error the callback raised
      # @api private
      # @return [StandardError] the error the callback raised
      # @example Raise the error a callback raised
      #   raise error.error
      attr_reader :error

      # Run a callback, tagging the error it raises
      #
      # An error already tagged, by a callback that runs within another, is raised as it is.
      #
      # @api private
      # @yield [] runs the callback
      # @return [Object] what the callback returned
      # @raise [CallbackError] if the callback raised
      # @example Run the hook of a response
      #   X::Core::CallbackError.tagging { on_response.call(summary) }
      def self.tagging
        yield
      rescue CallbackError
        raise
      rescue => e
        raise new(e)
      end

      # Initialize a new CallbackError
      #
      # It takes the message of the error it stands in for, which is read only if it escapes what runs the callback.
      #
      # @api private
      # @param error [StandardError] the error the callback raised
      # @return [CallbackError] a new instance
      # @example Tag the error a callback raised
      #   raise X::Core::CallbackError, error
      def initialize(error)
        super
        @error = error
      end
    end
    private_constant :CallbackError
  end
end
