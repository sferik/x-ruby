# frozen_string_literal: true

module X
  module Streaming
    # Stops the streams a streaming client runs, from any thread, for good
    #
    # A stream waits on the API for most of its life, so its block, which runs only when an object arrives, cannot stop
    # one that delivers nothing. Each stream runs in a thread the stopper knows, and stop raises Stopped in each, which
    # is delivered only as the stream waits on the API, ending a read, a connection, or a wait to reconnect, and never
    # the code around them, nor the block of the stream or the on_response of its client, which guard runs, so that
    # what either does with an object, or on_response with a failed response, is never cut short. A stopper that was
    # stopped stays stopped, so a stream that had not begun when stop was called, as one a thread started just before
    # it may not have, never begins.
    #
    # Internal to x-streaming: StreamingClient#stop stops the streams it runs with it.
    #
    # @api private
    class Stopper
      # Raised in the thread of a stream that stop stops, or by a run that reads the stopper was stopped, which run
      # rescues to return nil
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

      # A callable that calls another with guard, or nil for no callable
      #
      # stop does not cut short the callable it calls, as it does not the block of guard.
      #
      #
      # @api private
      # @param callable [#call, nil] the callable
      # @return [Proc, nil] the callable that guards it, or nil if it is nil
      # @example Guard the on_response of a client
      #   X::Streaming::Stopper.guarding(client.on_response)
      def self.guarding(callable) = callable && ->(*arguments) { guard { callable.call(*arguments) } }

      # Initialize a stopper that knows no stream, and was not stopped
      #
      # @api private
      # @return [Stopper] a new stopper
      def initialize
        @streams = [] #: Array[Thread]
        @lock = Mutex.new
        @stopped = false
      end

      # Whether the stopper was stopped
      #
      # @api private
      # @return [Boolean] true once stop was called
      # @example Check whether the streams of a streaming client were stopped
      #   stopper.stopped? # => false
      def stopped? = @stopped

      # Run a stream that stop stops, unless the stopper was stopped
      #
      # The thread of the stream is known to stop while the stream runs alone, under the lock stop raises under, so
      # stop raises in no thread that is not running a stream. Whether the stopper was stopped is read under that lock
      # too, and stop marks it before it takes the lock, so either the thread is known by the time stop raises, or the
      # stream reads that the stopper was stopped and never begins. A stop that arrives as the stream ends is
      # delivered once the thread is no longer known to stop, and rescued here, so it never reaches the caller.
      #
      # @api private
      # @yield runs the stream
      # @return [Object, nil] what the stream returned, or nil if stop stopped it, or was called before it began
      # @example Run a stream that stop stops
      #   stopper.run { reconnect_handler.handle(consumer) { |deliver, alive| read(deliver, alive) } }
      def run
        Thread.handle_interrupt(Stopped => :never) do
          raise Stopped unless @lock.synchronize { @streams << Thread.current unless stopped? }

          begin
            Thread.handle_interrupt(Stopped => :on_blocking) { yield }
          ensure
            @lock.synchronize { @streams.delete(Thread.current) }
          end
        end
      rescue Stopped
        nil
      end

      # Stop every stream the stopper runs, and every one it is asked to run later
      #
      # It may be called from the trap of a signal, where no lock can be waited for, and where the thread that holds
      # the lock may be the one the trap interrupted, so it marks the stopper stopped without the lock, and raises in
      # the streams under the lock only if it takes it at once. Otherwise a thread of its own waits for the lock and
      # raises in them, which it does not wait for, since the thread that holds the lock may be waiting for it to
      # return.
      #
      # @api private
      # @return [nil]
      # @example Stop the streams of a streaming client
      #   stopper.stop # => nil
      def stop
        @stopped = true
        lock_at_once ? interrupt_and_unlock : Thread.new { @lock.synchronize { interrupt } }
        nil
      end

      private

      # Take the lock if no thread holds it, without waiting for it
      #
      # @api private
      # @return [Boolean] true if it took the lock, or false if a thread holds it, or it cannot be taken here
      def lock_at_once
        @lock.try_lock
      rescue ThreadError
        false
      end

      # Raise Stopped in each stream the stopper runs, and release the lock this took
      # @api private
      # @return [void]
      def interrupt_and_unlock
        interrupt
      ensure
        @lock.unlock
      end

      # Raise Stopped in the thread of each stream the stopper runs, under the lock
      # @api private
      # @return [void]
      def interrupt = @streams.each { |thread| thread.raise(Stopped) }
    end
    private_constant :Stopper
  end
end
