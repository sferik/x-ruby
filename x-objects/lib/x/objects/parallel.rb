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
      # @api private
      # @param items [Enumerable] the items to map
      # @param concurrency [Integer] the maximum number of concurrent threads
      # @yield [Object] each item
      # @return [Array] the results in the same order as the items
      # @raise [Exception] the first exception raised by any block
      def map(items, concurrency: DEFAULT_CONCURRENCY, &block)
        items = items.to_a
        results = [] #: Array[untyped]
        queue = Queue.new
        items.each_index { |index| queue << index }
        queue.close
        threads = Array.new([concurrency, items.size].min) { worker(queue, items, results, &block) }
        threads.each(&:value)
        results
      end

      private

      # Start a worker thread that drains the queue
      #
      # @api private
      # @param queue [Queue] the queue of item indexes
      # @param items [Array] the items to map
      # @param results [Array] the results to fill
      # @yield [Object] each item
      # @return [Thread] the worker thread
      def worker(queue, items, results, &block)
        Thread.new do
          Thread.current.report_on_exception = false
          while (index = queue.deq)
            results[index] = block.call(items.fetch(index))
          end
        end
      end
    end
  end
end
