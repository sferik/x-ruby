# frozen_string_literal: true

require_relative "streaming_client"

module X
  module Streams
    # The streaming method mixed into a client, which builds a streaming client of the client
    #
    # The x gem includes it into X::Client. With x-core and x-streams alone, include it yourself:
    # X::Client.include(X::Streams::API), or build a streaming client of a client with X::StreamingClient.new. It
    # passes the object it is included into to the streaming client as its client, which is an X::Client, so it belongs
    # in X::Client or a subclass.
    #
    # @api public
    module API
      # A client for the streaming endpoints, which reads and reconnects differently
      #
      # Each call builds a new streaming client, so the one a stream runs on is kept in a variable to stop it with
      # {StreamingClient#stop}, and a streaming client that was stopped, which stays stopped, is replaced by another.
      #
      # @api public
      # @param read_timeout [Integer, Float, nil] the timeout for reading from a stream in seconds, as
      #   {StreamingClient#initialize} takes it
      # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops, as
      #   {StreamingClient#initialize} takes it
      # @param on_reconnect [#call, nil] a callable passed the error that dropped a stream and the seconds it waits
      #   before each reconnect, as {StreamingClient#initialize} takes it, or nil for none
      # @return [StreamingClient] a streaming client that shares this client's credentials and settings
      # @raise [ArgumentError] if the read timeout is neither a finite number of seconds of at least 25 nor nil, the
      #   maximum number of reconnects is neither a count nor Float::INFINITY, or on_reconnect neither responds to call
      #   nor is nil
      # @example Stream filtered posts, giving up after five reconnects in a row
      #   client.streaming(max_reconnects: 5).stream("tweets/search/stream") { |post| puts post }
      # @example Log each reconnect of a stream
      #   client.streaming(on_reconnect: ->(error, wait) { logger.warn("#{error.message}; reconnecting in #{wait}s") })
      def streaming(read_timeout: StreamingClient::DEFAULT_READ_TIMEOUT, max_reconnects: StreamingClient::DEFAULT_MAX_RECONNECTS, on_reconnect: nil)
        StreamingClient.new(_ = self, read_timeout:, max_reconnects:, on_reconnect:)
      end
    end
  end
end
