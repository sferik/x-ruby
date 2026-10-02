# frozen_string_literal: true

module X
  module Streaming
    # Wraps an error a callback of a stream raised, so that it is not taken for an error of the stream
    #
    # A stream runs on_response, the from_response of its object_class, and its block inside the request that reads
    # it, where an IOError or a SystemCallError a callback raised would be taken for a connection that dropped, and an
    # X::ServiceUnavailable for the response of the stream, and the stream reconnected after it. So a callback's error
    # is wrapped in this, which neither X::Client#get_stream nor the reconnects of a stream take for one of theirs, and
    # raised as it was once the stream is left.
    #
    # Internal to x-streaming: StreamParser tags the errors of a callback with it, as StreamingClient tags those of the
    # on_response its stream client is passed a failed response with, and ReconnectHandler raises the error it holds
    # in its place.
    #
    # @api private
    class CallbackError < StandardError
      # The error the callback raised
      # @api private
      # @return [StandardError] the error
      attr_reader :error

      # A callable that tags the error another raises, or nil for no callable
      #
      # X::Client#get_stream tags the error of the on_response it passes a failed response as its own, and raises it
      # as it was, so a callable whose error is not to be taken for one of the stream raises this itself.
      #
      # @api private
      # @param callable [#call, nil] the callable
      # @return [Proc, nil] the callable that tags its errors, or nil if it is nil
      # @example Tag the errors of the on_response of a client
      #   X::Streaming::CallbackError.tagging(client.on_response)
      def self.tagging(callable)
        callable && lambda do |*arguments|
          callable.call(*arguments)
        rescue => e
          raise new(e)
        end
      end

      # Initialize a new CallbackError
      # @api private
      # @param error [StandardError] the error the callback raised
      # @return [CallbackError] a new instance
      def initialize(error)
        super
        @error = error
      end
    end
    private_constant :CallbackError
  end
end
