require "monitor"

module X
  module Objects
    # A thread-safe slot that holds one lazily computed value
    # @api private
    class Memo
      # Marker for a slot that holds no value yet
      UNSET = Object.new.freeze

      # Initialize an empty memo
      #
      # @api private
      # @return [Memo] a new memo
      def initialize
        @monitor = Monitor.new
        @value = UNSET
      end

      # Fetch the value, computing and storing it on first access
      #
      # @api private
      # @yield computes the value when none is stored
      # @return [Object] the memoized value
      def fetch
        @monitor.synchronize do
          @value = yield if @value.equal?(UNSET)
          @value
        end
      end

      # Store a value, replacing any memoized value
      #
      # @api private
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def store(value)
        @monitor.synchronize { @value = value }
      end
    end
  end
end
