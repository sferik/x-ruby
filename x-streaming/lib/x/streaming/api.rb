# frozen_string_literal: true

require_relative "streaming_client"

module X
  module Streaming
    # The streaming method mixed into a client, which builds a streaming client of the client
    #
    # The x gem includes it into X::Client. With x-core and x-streaming alone, include it yourself:
    # X::Client.include(X::Streaming::API), or build a streaming client of a client with X::StreamingClient.new. It
    # passes the object it is included into to the streaming client as its client, which is an X::Client, so it belongs
    # in X::Client or a subclass.
    #
    # @api public
    module API
      # A client for the streaming endpoints, which reads and reconnects differently
      #
      # @api public
      # @param read_timeout [Integer, Float, nil] the timeout for reading from a stream in seconds, as
      #   {StreamingClient#initialize} takes it
      # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops, as
      #   {StreamingClient#initialize} takes it
      # @return [StreamingClient] a streaming client that shares this client's credentials and settings
      # @raise [ArgumentError] if the read timeout is neither a finite number of seconds greater than 0 nor nil, or the
      #   maximum number of reconnects is neither a count nor Float::INFINITY
      # @example Stream filtered posts, giving up after five reconnects in a row
      #   client.streaming(max_reconnects: 5).stream("tweets/search/stream") { |post| puts post }
      def streaming(read_timeout: StreamingClient::DEFAULT_READ_TIMEOUT, max_reconnects: StreamingClient::DEFAULT_MAX_RECONNECTS)
        StreamingClient.new(_ = self, read_timeout:, max_reconnects:)
      end
    end
  end
end
