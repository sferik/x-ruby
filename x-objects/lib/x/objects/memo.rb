# frozen_string_literal: true

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

      # Check whether a value is stored, whether computed or stored
      #
      # It reads the slot without the lock, since a value, once stored, is only ever replaced by another.
      #
      # @api private
      # @return [Boolean] true if the memo holds a value, which may be nil
      def stored? = !@value.equal?(UNSET)

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
