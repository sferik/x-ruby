# frozen_string_literal: true

module X
  module Core
    # Tells the errors of the socket the body of a stream is read from apart from those of the code that reads it
    #
    # The block of Client#get_stream reads the body of the response, and an error of a socket raised while it is read,
    # such as the IOError of a body that dropped, or a read that timed out, is a NetworkError, which a stream
    # reconnects after, while the block's own errors are raised as they were. The class of an error does not tell
    # which it is, since code of the block's own, such as a write to a full disk, raises the errors a socket does. So
    # the response the block is passed reads its body through this, which notes the errors read_body raises from the
    # socket, and not those of the block read_body passes each chunk to, or of what it appends each chunk to.
    #
    # Internal to x-core: the stream Client#get_stream opens extends its response with it, and raises an error as a
    # NetworkError only when socket_error? says it is one.
    #
    # @api private
    module StreamBody
      # The errors read_body raised from the socket, each held as its own key for as long as anything else holds it
      SOCKET_ERRORS = ObjectSpace::WeakMap.new
      private_constant :SOCKET_ERRORS

      # Check whether an error is one read_body raised from the socket
      #
      # @api private
      # @param error [Exception] the error
      # @return [Boolean] true if read_body raised it from the socket
      # @example Check an error a stream raised
      #   X::Core::StreamBody.socket_error?(error) # => false
      def self.socket_error?(error) = SOCKET_ERRORS[error].equal?(error)

      # Read the body, noting the errors of its socket
      #
      # They are the network errors reading it raises that the sink of its chunks did not raise.
      #
      # @api private
      # @param failed [Array<Exception>] the errors the sink of the chunks raised
      # @yield reads the body
      # @return [Object] what the block returns
      # @raise [StandardError] whatever the block raises
      def self.noting(failed)
        yield
      rescue => e
        SOCKET_ERRORS[e] = e if Connection.network_error?(e) && !failed.include?(e)
        raise
      end

      # The block read_body passes each chunk to
      #
      # It notes the error the sink of the chunks raises, which is not the socket's.
      #
      # @api private
      # @param sink [Proc] the block or dest each chunk is passed to
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

      # Read the body as Net::HTTPResponse#read_body does, noting socket errors
      #
      # The body is passed to the block, or to dest, a chunk at a time, so that an error of either is told apart from
      # one of the socket, and dest is returned, as Net::HTTPResponse#read_body returns it. A body read whole, or read
      # with both dest and a block, which Net::HTTPResponse#read_body refuses, is read as it reads it.
      #
      # @api private
      # @param dest [#<<, nil] what to append each chunk to, or nil to pass each to the block, or read the body whole
      # @yieldparam chunk [String] each chunk of the body, as it arrives
      # @return [Object] the body, or dest
      # @raise [StandardError] whatever the socket, the block, or dest raises
      def read_body(dest = nil, &block)
        failed = [] #: Array[Exception]
        StreamBody.noting(failed) do
          if dest.nil?.equal?(block.nil?)
            super
          else
            body = super(&StreamBody.passing(block || ->(chunk) { dest << chunk }, failed))
            dest || body
          end
        end
      end
    end
    private_constant :StreamBody
  end
end
