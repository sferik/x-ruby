# frozen_string_literal: true

require_relative "errors/conflict"
require_relative "errors/invalid_response"
require_relative "errors/network_error"
require_relative "errors/server_error"
require_relative "errors/too_many_requests"

module X
  module Core
    # Reconnects a stream that drops, backing off as X recommends
    #
    # A stream that ends, loses its connection, or cannot open one, as when the connection is refused, reconnects at
    # once, then after a delay that grows by a quarter second each attempt, up to 16 seconds. A server error, a 409
    # Conflict, or a line that is not JSON backs off from 5 seconds, doubling each attempt, up to 320 seconds. A rate
    # limit waits until it resets, or from a minute, doubling each attempt. Delivering an object starts the count over.
    #
    # Internal to x-core: StreamingClient reconnects with it, and max_reconnects is set on the streaming client.
    #
    # @api private
    class ReconnectHandler
      # Default maximum number of reconnects in a row, which is unlimited, since a stream is meant to run until stopped
      DEFAULT_MAX_RECONNECTS = Float::INFINITY
      # Seconds the wait grows by after each dropped connection
      NETWORK_BACKOFF_STEP = 0.25
      # Longest wait after a dropped connection, in seconds
      MAX_NETWORK_BACKOFF = 16
      # First wait after a server error, in seconds
      HTTP_BACKOFF_START = 5
      # Longest wait after a server error, in seconds
      MAX_HTTP_BACKOFF = 320
      # First wait after a rate limit, in seconds, for a limit that does not say when it resets
      RATE_LIMIT_BACKOFF_START = 60
      # The errors a stream reconnects after, which come from the server or the connection rather than the request
      RECONNECTABLE_ERRORS = [NetworkError, ServerError, Conflict, TooManyRequests, InvalidResponse].freeze

      # Raised in place of an error the consumer of a stream raised, which is its cause, so that the stream stops
      ConsumerError = Class.new(StandardError) #: singleton(StandardError)
      private_constant :ConsumerError

      # The maximum number of times in a row to reconnect without delivering an object
      # @api private
      # @return [Integer, Float] the maximum number of reconnects, or Float::INFINITY for no limit
      # @example Read the maximum reconnects
      #   handler.max_reconnects # => 5
      attr_reader :max_reconnects

      # Initialize a new reconnect handler
      #
      # @api private
      # @param max_reconnects [Integer, Float] the maximum number of reconnects in a row, or Float::INFINITY
      # @return [ReconnectHandler] a new instance
      # @example Create a reconnect handler
      #   handler = X::Core::ReconnectHandler.new(max_reconnects: 5)
      def initialize(max_reconnects: DEFAULT_MAX_RECONNECTS)
        @max_reconnects = max_reconnects
      end

      # Run a stream, running it again whenever it drops
      #
      # An error raised by the consumer stops the stream, even one that would otherwise reconnect, and reaches the
      # caller, as does any error that is not one a stream reconnects after, such as one raised by the on_response
      # of the client or by the class an object is parsed into. The stream is run again with while rather than
      # Kernel#loop, which rescues StopIteration, so that a StopIteration raised from an Enumerator that has run
      # out, wherever it is raised, reaches the caller too, rather than end the stream without a word.
      #
      # @api private
      # @param consumer [Proc] the block that receives each object
      # @yield [deliver] runs the stream once
      # @yieldparam deliver [Proc] the block to pass each object to, which passes it on to the consumer
      # @return [nil] once the stream ends with no reconnects left
      # @raise [NetworkError, ServerError, Conflict, TooManyRequests, InvalidResponse] if the stream fails with no
      #   reconnects left
      # @example Reconnect a stream
      #   handler.handle(->(post) { puts post }) { |deliver| read_stream(&deliver) }
      def handle(consumer, &stream)
        state = {reconnects: 0} #: state
        deliver = delivery_to(consumer, state)
        while run_once(stream, deliver, state); end
      rescue ConsumerError => e
        raise cause_of(e)
      end

      private

      # Run a stream once, waiting for the next reconnect when it drops or ends
      # @api private
      # @param stream [Proc] runs the stream once
      # @param deliver [Proc] the block to pass each object to
      # @param state [Hash] the count of reconnects, for one call to handle
      # @return [Boolean] true to run the stream again, or false once it ends with no reconnects left
      # @raise [NetworkError, ServerError, Conflict, TooManyRequests, InvalidResponse] if the stream fails with no
      #   reconnects left
      def run_once(stream, deliver, state)
        stream.call(deliver)
        !out_of_reconnects?(nil, state)
      rescue *RECONNECTABLE_ERRORS => e
        raise if out_of_reconnects?(e, state)

        true
      end

      # The error a consumer raised, which a consumer error stands in for
      # @api private
      # @param error [ConsumerError] the error raised in its place
      # @return [StandardError] the error the consumer raised
      def cause_of(error)
        error.cause #: StandardError
      end

      # Check whether the reconnects are spent, waiting for the next if not
      # @api private
      # @param error [StandardError, nil] the error that dropped the stream, or nil if the stream ended
      # @param state [Hash] the count of reconnects, for one call to handle
      # @return [Boolean] true if no reconnects remain, or false once it has waited for the next
      def out_of_reconnects?(error, state)
        reconnects = state[:reconnects] += 1
        return true if reconnects > max_reconnects

        sleep(error ? backoff(error, reconnects) : network_backoff(reconnects))
        false
      end

      # A block that passes an object to the consumer and starts the count over
      # @api private
      # @param consumer [Proc] the block that receives each object
      # @param state [Hash] the count of reconnects, for one call to handle
      # @return [Proc] the block
      def delivery_to(consumer, state)
        lambda do |object|
          state[:reconnects] = 0
          consumer.call(object)
        rescue
          raise ConsumerError
        end
      end

      # The wait before a reconnect, by the kind of error
      # @api private
      # @param error [StandardError] the error that dropped the stream
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Float, Integer] the seconds to wait
      def backoff(error, reconnects)
        case error
        when NetworkError then network_backoff(reconnects)
        when TooManyRequests then rate_limit_backoff(error, reconnects)
        else http_backoff(reconnects)
        end
      end

      # The wait before a reconnect after a rate limit, at least until it resets
      # @api private
      # @param error [TooManyRequests] the error the connection raised
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Integer] the seconds to wait
      def rate_limit_backoff(error, reconnects)
        backoff = [RATE_LIMIT_BACKOFF_START << (reconnects - 1), MAX_HTTP_BACKOFF].min
        [error.retry_after, backoff].compact.max #: Integer
      end

      # The wait before a reconnect after a dropped connection
      # @api private
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Float, Integer] the seconds to wait
      def network_backoff(reconnects) = [NETWORK_BACKOFF_STEP * (reconnects - 1), MAX_NETWORK_BACKOFF].min

      # The wait before a reconnect after a server error, a refusal, or a bad line
      # @api private
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Integer] the seconds to wait
      def http_backoff(reconnects) = [HTTP_BACKOFF_START << (reconnects - 1), MAX_HTTP_BACKOFF].min
    end
  end
end
