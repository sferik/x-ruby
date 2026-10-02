# frozen_string_literal: true

module X
  module Streaming
    # Stops the streams a streaming client runs, from any thread
    #
    # A stream waits on the API for most of its life, so its block, which runs only when an object arrives, cannot stop
    # one that delivers nothing. Each stream runs in a thread the stopper knows, and stop raises Stopped in each, which
    # is delivered only as the stream waits on the API, ending a read, a connection, or a wait to reconnect, and never
    # the code around them, nor the block of the stream or the on_response of its client, which guard runs, so that
    # what either does with an object is never cut short.
    #
    # Internal to x-streaming: StreamingClient#stop stops the streams it runs with it.
    #
    # @api private
    class Stopper
      # Raised in the thread of a stream that stop stops, which run rescues to return nil
      class Stopped < StandardError; end
      private_constant :Stopped

      # Run a block that stop does not cut short, deferring a stop until it returns
      #
      # @api private
      # @yield the block
      # @return [Object] what the block returns
      # @example Pass an object to the block of a stream
      #   X::Streaming::Stopper.guard { block.call(post) }
      def self.guard(&) = Thread.handle_interrupt(Stopped => :never, &)

      # Initialize a stopper that knows no stream
      #
      # @api private
      # @return [Stopper] a new stopper
      def initialize
        @streams = [] #: Array[Thread]
        @lock = Mutex.new
      end

      # Run a stream, which stop stops in the thread it runs in
      #
      # The thread of the stream is known to stop while the stream runs alone, under the lock stop raises under, so
      # stop raises in no thread that is not running a stream. A stop that arrives as the stream ends is delivered once
      # the thread is no longer known to stop, and rescued here, so it never reaches the caller.
      #
      # @api private
      # @yield runs the stream
      # @return [Object, nil] what the stream returned, or nil if stop stopped it
      # @example Run a stream that stop stops
      #   stopper.run { reconnect_handler.handle(consumer) { |deliver, alive| read(deliver, alive) } }
      def run
        Thread.handle_interrupt(Stopped => :never) do
          @lock.synchronize { @streams << Thread.current }
          begin
            Thread.handle_interrupt(Stopped => :on_blocking) { yield }
          ensure
            @lock.synchronize { @streams.delete(Thread.current) }
          end
        end
      rescue Stopped
        nil
      end

      # Stop every stream the stopper runs
      #
      # @api private
      # @return [Integer] the number of streams it stopped
      # @example Stop the streams of a streaming client
      #   stopper.stop # => 1
      def stop = @lock.synchronize { @streams.each { |thread| thread.raise(Stopped) }.size }
    end
    private_constant :Stopper
  end
end
