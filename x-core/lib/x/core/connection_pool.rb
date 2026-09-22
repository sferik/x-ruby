# frozen_string_literal: true

require "net/http"

module X
  module Core
    # The open HTTP connections of a Connection, kept to be used again by the next request to the same host
    #
    # A connection is used by one request at a time: a request takes an idle connection, or opens one, and gives
    # it back once it has read the response. A request that fails closes its connection instead, and so does one
    # that finishes after clear. A forked process opens
    # connections of its own rather than share its parent's.
    #
    # @api private
    class ConnectionPool
      # Most idle connections kept open to each host
      MAX_IDLE = 8

      # Initialize an empty pool
      #
      # @api private
      # @return [ConnectionPool] a new pool
      def initialize
        @lock = Mutex.new
      end

      # Run a block with an open connection, keeping it for later if the block returns
      #
      # The block is told whether the connection was one the pool had kept open, since a connection the peer closed
      # while it was idle fails the request that takes it, where one opened for the request did not go stale.
      #
      # @api private
      # @param key [Array] the scheme, host, and port the connection is to
      # @param open [Proc] builds a connection to the host, when none is idle
      # @param fresh [Boolean] whether to open a connection even when one is idle
      # @yield [Net::HTTP, Boolean] the started connection, and whether it came from the pool
      # @return [Object] what the block returns
      def with(key, open, fresh: false)
        pool, http_client, pooled = checkout(key, open, fresh)
        kept = nil
        begin
          result = yield http_client, pooled
          kept = checkin(key, http_client, pool)
          result
        ensure
          close(http_client) unless kept
        end
      end

      # Close every idle connection, and each one in use once its request finishes
      #
      # A forked process leaves the connections its parent opened alone, since closing one would end the parent's
      # TLS session over the socket they share.
      #
      # @api private
      # @return [void]
      def clear
        idle = @lock.synchronize do
          forget_after_fork
          @idle.values.flatten.tap { @idle = {} }
        end
        idle.each { |http_client| close(http_client) }
      end

      private

      # Take an idle connection to a host, or open one
      # @api private
      # @param key [Array] the scheme, host, and port
      # @param open [Proc] builds a connection to the host
      # @param fresh [Boolean] whether to open a connection even when one is idle
      # @return [Array(Hash, Net::HTTP, bool)] the idle connections the connection returns to, the started
      #   connection, and whether it was idle rather than opened for this request
      def checkout(key, open, fresh)
        pool, idle = @lock.synchronize do
          forget_after_fork
          [@idle, (@idle[key]&.pop unless fresh)]
        end
        http_client = idle || open.call
        http_client.start unless http_client.started?
        [pool, http_client, !idle.nil?]
      end

      # Keep a connection for later, unless the pool was cleared or is full
      # @api private
      # @param key [Array] the scheme, host, and port
      # @param http_client [Net::HTTP] the connection
      # @param pool [Hash] the idle connections when the connection was taken, which clear replaces
      # @return [Array<Net::HTTP>, nil] the idle connections to the host, or nil if the connection was not kept
      def checkin(key, http_client, pool)
        @lock.synchronize do
          idle = @idle[key] ||= []
          idle.push(http_client) if pool.equal?(@idle) && idle.size < MAX_IDLE
        end
      end

      # Drop the connections a parent process opened, which a fork must not share
      #
      # The first call in a process, which is the first in a new pool, starts the pool with no connections.
      #
      # @api private
      # @return [void]
      def forget_after_fork
        return if @pid.eql?(Process.pid)

        @pid = Process.pid
        @idle = {}
      end

      # Close a connection, unless it is closed already
      # @api private
      # @param http_client [Net::HTTP] the connection
      # @return [void]
      def close(http_client)
        http_client.finish
      rescue IOError
        nil
      end
    end
  end
end
