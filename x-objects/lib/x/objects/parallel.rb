# frozen_string_literal: true

module X
  module Objects
    # Runs blocks across a bounded pool of threads
    # @api private
    module Parallel
      extend self

      # Map over items concurrently while preserving order
      #
      # Every item is given its place in the results before any thread starts, so that a worker never resizes the
      # array it writes into, which keeps the writes of the workers safe on a Ruby that runs them in parallel.
      #
      # A block that raises stops the items not yet begun, since each is a request the API bills, and once the
      # items already begun have finished, the first error raised is raised again. An interruption of the wait,
      # such as a timeout, a shutdown, or a signal, stops them the same way, rather than leave the threads to
      # spend what the caller is no longer waiting for.
      #
      # @api private
      # @param items [Enumerable] the items to map
      # @param concurrency [Integer] the maximum number of concurrent threads, which callers check is at least one
      # @yield [Object] each item
      # @return [Array] the results in the same order as the items
      # @raise [StandardError] the first error raised by any block
      def map(items, concurrency:, &block)
        items = items.to_a
        results = Array.new(items.size) #: Array[untyped]
        queue = Queue.new
        items.each_index { |index| queue << index }
        queue.close
        errors = Queue.new
        drain(queue, Array.new([concurrency, items.size].min) { worker(queue, errors, items, results, &block) })
        raise errors.deq unless errors.empty?

        results
      end

      private

      # Wait for the workers, emptying the queue however the wait ends
      #
      # @api private
      # @param queue [Queue] the queue of item indexes
      # @param threads [Array<Thread>] the worker threads
      # @return [void]
      def drain(queue, threads)
        threads.each(&:join)
      ensure
        queue.clear
      end

      # Start a worker thread that drains the queue, emptying it if the block raises
      #
      # @api private
      # @param queue [Queue] the queue of item indexes
      # @param errors [Queue] the errors the block raised, in the order it raised them
      # @param items [Array] the items to map
      # @param results [Array] the results to fill
      # @yield [Object] each item
      # @return [Thread] the worker thread
      def worker(queue, errors, items, results, &block)
        Thread.new do
          while (index = queue.deq)
            results[index] = block.call(items.fetch(index))
          end
        rescue => e
          errors << e
          queue.clear
        end
      end
    end
  end
end
