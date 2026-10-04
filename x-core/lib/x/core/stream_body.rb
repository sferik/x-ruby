# frozen_string_literal: true

require_relative "errors/network_error"

module X
  module Core
    # Reads the body of a stream, raising the errors of the socket it is read from as a NetworkError
    #
    # The block of Client#get_stream reads the body of the response, and an error of a socket raised while it is read,
    # such as the IOError of a body that dropped, or a read that timed out, is a NetworkError, which a stream
    # reconnects after, while the block's own errors are raised as they were. The class of an error does not tell
    # which it is, since code of the block's own, such as a write to a full disk, raises the errors a socket does. So
    # the StreamResponse the block is passed reads its body through this, which raises a NetworkError for the errors
    # read_body raises from the socket, and not for those of the block read_body passes each chunk to.
    #
    # Internal to x-core: StreamResponse#read_body reads the body of a stream with it, and the stream
    # Client#get_stream opens raises an error untagged, as its own rather than the block's, only when socket_error?
    # says read_body raised it.
    #
    # @api private
    module StreamBody
      # The NetworkErrors read_body raised for the socket, each held as its own key for as long as anything else holds
      # it
      SOCKET_ERRORS = ObjectSpace::WeakMap.new
      private_constant :SOCKET_ERRORS

      # Check whether an error is the NetworkError read_body raised for the socket
      #
      # @api private
      # @param error [Exception] the error
      # @return [Boolean] true if read_body raised it for an error of the socket
      # @example Check an error a stream raised
      #   X::Core::StreamBody.socket_error?(error) # => false
      def self.socket_error?(error) = SOCKET_ERRORS[error].equal?(error)

      # Read the body, raising the errors of its socket as a NetworkError
      #
      # They are the network errors reading it raises that the sink of its chunks did not raise. The NetworkError is
      # built as Connection builds one for a request that failed, naming the request of the stream, with the error of
      # the socket as its cause, and noted, so that the stream raises it as it is.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request of the stream, which the NetworkError names
      # @param failed [Array<Exception>] the errors the sink of the chunks raised
      # @yield reads the body
      # @return [Object] what the block returns
      # @raise [NetworkError] if the block raises an error of the socket
      # @raise [StandardError] whatever else the block raises
      def self.reading(uri, failed)
        yield
      rescue => e
        raise unless Connection.network_error?(e) && !failed.include?(e)

        error = NetworkError.new("Network error: #{e}", http_method: :get, uri:)
        raise SOCKET_ERRORS[error] = error
      end

      # The block read_body passes each chunk to
      #
      # It notes the error the sink of the chunks raises, which is not the socket's.
      #
      # @api private
      # @param sink [Proc] the block each chunk is passed to
      # @param failed [Array<Exception>] the errors of the sink, which the error it raises is added to
      # @return [Proc] the block
      def self.passing(sink, failed)
        lambda do |chunk|
          sink.call(chunk)
        rescue => e
          failed << e
          raise
        end
      end
    end
    private_constant :StreamBody
  end
end
