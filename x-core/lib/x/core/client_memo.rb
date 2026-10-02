# frozen_string_literal: true

module X
  module Core
    # What the gems that extend a client keep on it, for as long as it authenticates as it does, included into
    # ClientInternals
    #
    # x-objects keeps the identifier of the user a lookup found for the credentials of a client here, so that it looks
    # the user up once. A value is kept with the authenticator of the client when it was kept, and read only while the
    # client authenticates with that authenticator, since what it says may be true of those credentials alone. It is
    # kept under a lock, so that threads that share a client read and keep values together.
    #
    # The memo is held by the internals of a client, as the app-only copy of a client is, rather than by the client,
    # so a frozen client keeps values as well, and a copy made with dup or clone, which holds the same internals and
    # authenticator, shares them. A copy made with {Client#with} holds internals of its own, and keeps its own values.
    #
    # @api private
    module ClientMemo
      # The value kept under a key for the authenticator the client holds
      #
      # It is what {Client#memoized} does.
      #
      # @api private
      # @param key [Symbol] the key, which names the gem that keeps it
      # @return [Object, nil] the value, or nil if none is kept for the authenticator of the client
      def memoized(key)
        @memo_lock.synchronize do
          owner, value = @memo[key]
          value if owner.equal?(authenticator)
        end
      end

      # Keep a value under a key, for the authenticator of the client
      #
      # It is what {Client#memoize} does.
      #
      # @api private
      # @param key [Symbol] the key, which names the gem that keeps it
      # @param value [Object] the value
      # @return [Object] the value
      def memoize(key, value)
        @memo_lock.synchronize { @memo[key] = [authenticator, value] }
        value
      end

      private

      # Start with nothing kept
      # @api private
      # @return [void]
      def initialize_memo
        @memo = {}
        @memo_lock = Mutex.new
      end
    end
    private_constant :ClientMemo
  end
end
