# frozen_string_literal: true

module X
  module Streams
    # Stops the streams a streaming client runs, from any thread, for good
    #
    # A stream waits on the API for most of its life, so its block, which runs only when an object arrives, cannot stop
    # one that delivers nothing. Each stream runs in a thread the stopper knows, and stop raises Stopped in each, which
    # is delivered as the stream next blocks, mostly as it waits on the API, ending a read, a connection, or a wait to
    # reconnect, but never in the block of the stream, the on_response or on_reconnect of its client, or the
    # save_tokens a refresh is reported to, which guard runs, so that what each does is never cut short. A stopper
    # that was stopped stays stopped, so a stream that had not begun when stop was called, as one a thread started
    # just before it may not have, never begins.
    #
    # Internal to x-streams: StreamingClient#stop stops the streams it runs with it.
    #
    # @api private
    class Stopper
      # Raised in the thread of a stream that stop stops, or by a run that reads the stopper was stopped; each stopper
      # raises a subclass of its own, which only its run rescues to return nil
      #
      # It is not a StandardError, as Timeout::ExitException is not, so that a callback the stream runs where a stop is
      # delivered, as an object_class whose from_response looks something up or a load_tokens that reads a store, cannot
      # rescue it, and raise an error of its own or let the stream go on, rather than return nil.
      class Stopped < Exception; end # rubocop:disable Lint/InheritException
      private_constant :Stopped

      # A stream a stopper runs: the thread it runs in, whether it runs in a fiber a Fiber scheduler runs, and whether a
      # guarded block of it is running
      class Stream
        # The thread the stream runs in
        # @api private
        # @return [Thread] the thread
        attr_reader :thread

        # Whether a Fiber scheduler runs the non-blocking fiber of the stream
        #
        # It does for a stream in an Async task.
        #
        # Such a stream waits on the API in the scheduler, not in a read of its own, so a stop raised in its thread
        # would end the scheduler rather than the stream; stop raises in no such stream, which is stopped once its
        # block returns.
        #
        # @api private
        # @return [Boolean] true if a Fiber scheduler runs the fiber of the stream
        attr_reader :scheduled

        # Whether a guarded block of the stream is running
        # @api private
        # @return [Boolean] true while a guarded block of the stream runs
        attr_accessor :guarded

        # Initialize a stream that runs in the current fiber
        #
        # No guarded block of it is running.
        #
        # @api private
        # @return [Stream] a new stream
        def initialize
          @thread = Thread.current
          @scheduled = !Fiber.blocking? && !Fiber.scheduler.nil?
          @guarded = false
        end

        # Whether stop raises in the stream
        #
        # It does if no guarded block of the stream runs, and no Fiber scheduler runs it.
        #
        # @api private
        # @return [Boolean] true if stop raises in the thread of the stream
        def interruptible? = !guarded && !scheduled
      end
      private_constant :Stream

      # The key of the fiber-local variable that holds the stopper and the stream that run in the current fiber
      CURRENT = :__x_streams_stopper_current__
      private_constant :CURRENT

      # Run a block that stop does not cut short, deferring a stop until it returns
      #
      # No stop is held back in the thread while a guarded block of a stream runs, and stop raises in no stream whose
      # guarded block runs, so a stream whose block is held, as in a Fiber an Enumerator iterates, is not stopped in
      # the place of another stream of the same thread. A stop held back as the block began is discarded, and once the
      # block returns, a stream whose stopper was stopped is stopped the next time it waits on the API, as one stop
      # raises in is. A block that ends by raising, throwing, or breaking ends the stream as it does, since no stop was
      # held back to end the stream in its place as it unwinds.
      #
      # @api private
      # @yield the block
      # @return [Object] what the block returns
      # @example Pass an object to the block of a stream
      #   X::Streams::Stopper.guard { block.call(post) }
      def self.guard(&)
        stopper, stream = Thread.current[CURRENT]
        return Thread.handle_interrupt(Stopped => :never, &) unless stream

        result = guarding_stream(stream, &)
        stopper.__send__(:stop_returned, stream)
        result
      end

      # Run a block with a stream marked as running a guarded block
      #
      # The mark the stream had is restored after. The stream is marked before a stop held back as the block begins
      # is discarded, so that stop, which raises in no stream so marked, raises in it either before the discard or
      # not at all, and none is held back while the block runs. The stream is stopped once the block returns.
      #
      # @api private
      # @param stream [Stream] the stream
      # @yield the block
      # @return [Object] what the block returns
      def self.guarding_stream(stream)
        outer = stream.guarded
        begin
          stream.guarded = true
          discard_stop
          yield
        ensure
          stream.guarded = outer
        end
      end
      private_class_method :guarding_stream

      # Discard every stop held back in the current thread
      #
      # Each call of stop raises in a stream that is reading, and Ruby holds each back on its own, so a stream stopped
      # more than once holds back as many; each is discarded in turn until none is left, so that none cuts a block short
      # or reaches the caller once the stream returns.
      #
      # @api private
      # @return [nil]
      def self.discard_stop
        Thread.handle_interrupt(Stopped => :immediate) {}
      rescue Stopped
        retry
      end
      private_class_method :discard_stop

      # A callable that calls another, then stops its stream if it was stopped
      #
      # A stream calls it for each keep-alive, so a stream a Fiber scheduler runs, which stop raises in no read of,
      # is stopped at the next keep-alive X sends, within 20 seconds, though it delivers no object.
      #
      # @api private
      # @param callable [#call] the callable
      # @return [Proc] the callable that calls it and then stops the stream
      # @example Stop a stream at a keep-alive
      #   X::Streams::Stopper.checking(alive)
      def self.checking(callable)
        lambda do
          callable.call
          stopper, stream = Thread.current[CURRENT]
          stopper&.__send__(:stop_returned, stream)
        end
      end

      # The most seconds a stream a Fiber scheduler runs waits to reconnect before it checks whether it was stopped
      PAUSE = 1
      private_constant :PAUSE

      # Wait to reconnect, yielding the seconds to sleep, and stop the stream if stopped
      #
      # A stream a Fiber scheduler runs, which stop raises in no wait of, waits a second at a time, and is stopped
      # before each second and before it reconnects, so a stream that cannot connect, or that X answers with an error,
      # is stopped within a second, though it delivers no object and reads no keep-alive. Any other stream waits the
      # seconds at once, which stop cuts short.
      #
      # @api private
      # @param seconds [Integer, Float] the seconds to wait
      # @yieldparam seconds [Integer, Float] the seconds to sleep
      # @return [void]
      # @example Wait to reconnect
      #   X::Streams::Stopper.pausing(5) { |seconds| sleep(seconds) }
      def self.pausing(seconds)
        stopper, stream = Thread.current[CURRENT]
        return yield(seconds) unless stream&.scheduled

        while seconds.positive?
          stopper.__send__(:stop_returned, stream)
          yield [seconds, PAUSE].min
          seconds -= PAUSE
        end
        stopper.__send__(:stop_returned, stream)
      end

      # A callable that calls another with guard, or nil for no callable
      #
      # stop does not cut short the callable it calls, as it does not the block of guard.
      #
      # @api private
      # @param callable [#call, nil] the callable
      # @return [Proc, nil] the callable that guards it, or nil if it is nil
      # @example Guard the on_response of a client
      #   X::Streams::Stopper.guarding(client.on_response)
      def self.guarding(callable) = callable && ->(*arguments) { guard { callable.call(*arguments) } }

      # Initialize a stopper that knows no stream, and was not stopped
      #
      # @api private
      # @return [Stopper] a new stopper
      def initialize
        @streams = [] #: Array[Stream]
        @lock = Mutex.new
        @stopped = false
        @stop = Class.new(Stopped) #: singleton(Stopped)
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
      # The stream is known to stop while it runs alone, under the lock stop raises under, so stop raises in no
      # thread that is not running a stream. Whether the stopper was stopped is read under that lock too, and stop
      # marks it before it takes the lock, so either the stream is known by the time stop raises, or it reads that
      # the stopper was stopped and never begins. A stop that arrives as the stream ends is discarded once the stream
      # is no longer known to stop, so it never reaches the caller. Only a stop of this stopper is rescued, so one
      # of another, as for a stream that runs in the block of this one, ends the stream it stops.
      #
      # @api private
      # @yield runs the stream
      # @return [Object, nil] what the stream returned, or nil if stop stopped it, or was called before it began
      # @example Run a stream that stop stops
      #   stopper.run { reconnect_handler.handle(consumer) { |deliver, alive| read(deliver, alive) } }
      def run(&)
        Thread.handle_interrupt(Stopped => :never) do
          stream = Stream.new
          raise @stop unless @lock.synchronize { @streams << stream unless stopped? }

          running(stream, &)
        end
      rescue @stop
        nil
      end

      # Stop every stream the stopper runs, and every one it is asked to run later
      #
      # It may be called from the trap of a signal, where no lock can be waited for, and where the thread that holds
      # the lock may be the one the trap interrupted, so it marks the stopper stopped without the lock, and raises in
      # the streams under the lock only if it takes it at once. Otherwise a thread of its own waits for the lock and
      # raises in them, which it does not wait for, since the thread that holds the lock may be waiting for it to
      # return. A thread of its own raises in them too when it is called in the thread of a stream that is reading,
      # as from a trap that interrupts a stream on the main thread as it reads, since Stopped raised in the thread
      # that raises it is held back until the read the trap interrupted returns, which may be never. It raises in no
      # stream whose guarded block is running, which guard stops as the block returns.
      #
      # @api private
      # @return [nil]
      # @example Stop the streams of a streaming client
      #   stopper.stop # => nil
      def stop
        @stopped = true
        (!reading_here? && lock_at_once) ? interrupt_and_unlock : Thread.new { @lock.synchronize { interrupt } }
        nil
      end

      private

      # Run a stream the stopper knows as the stream of the current fiber
      #
      # The save_tokens of a refresh the stream makes is run under guard too, as its block is, so that a stop waits for
      # it to store the tokens rather than cut it short and leave the store with a refresh token X no longer accepts.
      #
      # @api private
      # @param stream [Stream] the stream
      # @yield runs the stream
      # @return [Object] what the stream returned
      def running(stream)
        outer = Thread.current[CURRENT] #: [Stopper, Stream]?
        begin
          Thread.current[CURRENT] = [self, stream]
          RefreshReportGuard.around(self.class.public_method(:guard)) { Thread.handle_interrupt(Stopped => :on_blocking) { yield } }
        ensure
          Thread.current[CURRENT] = outer
          @lock.synchronize { @streams.delete_if { |known| known.equal?(stream) } }
          self.class.__send__(:discard_stop)
        end
      end

      # Hold a stop back for a stream whose guarded block returned once it was stopped
      #
      # A stream a Fiber scheduler runs is stopped at once instead, since a stop held back in its thread would be
      # delivered as the scheduler waits, ending the scheduler rather than the stream. Each keep-alive read before
      # the stream next waits on the API holds back one more, which the stream discards with the rest as it ends.
      #
      # @api private
      # @param stream [Stream] the stream
      # @return [void]
      # @raise [Stopped] if the stopper was stopped and a Fiber scheduler runs the stream
      def stop_returned(stream)
        return unless stopped? && !stream.guarded
        raise @stop if stream.scheduled

        Thread.current.raise(@stop)
      end

      # Whether a stream the stopper runs is reading in the current thread
      #
      # It is as a trap that interrupts the read of a stream on its own thread runs.
      #
      # @api private
      # @return [Boolean] true if a stream runs in the current thread and no guarded block of it is running
      def reading_here? = @streams.any? { |stream| stream.thread.equal?(Thread.current) && stream.interruptible? }

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

      # Raise Stopped in each stream that is interruptible, under the lock
      # @api private
      # @return [void]
      def interrupt = @streams.each { |stream| stream.thread.raise(@stop) if stream.interruptible? }
    end
    private_constant :Stopper

    # Runs the save_tokens of a refresh a stream makes inside the guard of the stream
    #
    # x-core runs the callables a refresh reports to inside the callable under this fiber-local key, if one is set,
    # so that a stop waits for save_tokens to store the tokens rather than cut it short and leave the store with a
    # refresh token X no longer accepts.
    #
    # @api private
    module RefreshReportGuard
      # The fiber-local key x-core reads the guard from
      KEY = :x_core_refresh_report_guard

      # Run a block with a guard set for its refreshes, then set the one before again
      # @api private
      # @param guard [#call] the guard, which is passed a block to run
      # @yield runs the stream
      # @return [Object] what the block returns
      # @example Guard the refreshes of a stream
      #   RefreshReportGuard.around(Stopper.method(:guard)) { stream }
      def self.around(guard)
        outer = Thread.current[KEY]
        begin
          Thread.current[KEY] = guard
          yield
        ensure
          Thread.current[KEY] = outer
        end
      end
    end
    private_constant :RefreshReportGuard
  end
end
