module X
  module Objects
    # Runs blocks across a bounded pool of threads
    # @api private
    module Parallel
      # Default number of threads used for concurrent requests
      DEFAULT_CONCURRENCY = 8

      extend self

      # Map over items concurrently while preserving order
      #
      # A block that raises stops the items not yet begun, since each is a request the API bills, and once the
      # items already begun have finished, the first error raised is raised again.
      #
      # @api private
      # @param items [Enumerable] the items to map
      # @param concurrency [Integer] the maximum number of concurrent threads
      # @yield [Object] each item
      # @return [Array] the results in the same order as the items
      # @raise [StandardError] the first error raised by any block
      def map(items, concurrency: DEFAULT_CONCURRENCY, &block)
        items = items.to_a
        results = [] #: Array[untyped]
        queue = Queue.new
        items.each_index { |index| queue << index }
        queue.close
        errors = Queue.new
        Array.new([concurrency, items.size].min) { worker(queue, errors, items, results, &block) }.each(&:join)
        raise errors.deq unless errors.empty?

        results
      end

      private

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
