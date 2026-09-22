# frozen_string_literal: true

require "net/http"
require "openssl"
require "zlib"
require_relative "request_builder"

module X
  module Core
    # How a connection sends one request, and what it counts as a failure of the network, included into Connection
    # @api private
    module ConnectionRequest
      # Network errors that should be wrapped in NetworkError
      #
      # IOError covers EOFError, and a read from a socket closed under it. SystemCallError covers every error the
      # operating system reports for a socket, such as a refused, reset, or aborted connection, a network that is down
      # or has no route, or a write refused with EPIPE. Timeout::Error covers the open, read, and write timeouts of
      # Net::HTTP. A connection cut off mid-response can leave Net::HTTP a status line it cannot parse, or a compressed
      # body that Zlib cannot inflate, and a proxy that refuses to open a tunnel, such as with 407 Proxy Authentication
      # Required, raises a Net::ProtocolError.
      NETWORK_ERRORS = [
        IOError,
        Net::HTTPBadResponse,
        Net::ProtocolError,
        OpenSSL::SSL::SSLError,
        SocketError,
        SystemCallError,
        Timeout::Error,
        Zlib::Error
      ].freeze

      # Errors that say a connection kept open had been closed by the time a request was sent on it
      #
      # EOFError is read from a socket the peer closed, and a write to one it closed or reset is refused with EPIPE,
      # ECONNRESET, or ECONNABORTED. A timeout is not among them: a request that timed out waiting for its response
      # may have reached the API, which may have acted on it.
      STALE_CONNECTION_ERRORS = [EOFError, Errno::ECONNABORTED, Errno::ECONNRESET, Errno::EPIPE].freeze
      private_constant :NETWORK_ERRORS, :STALE_CONNECTION_ERRORS

      private

      # Send a request, once more on a new connection when a kept one had gone stale
      #
      # X, or a proxy between, can close a connection that is being kept open for the next request, and the request
      # that takes it then fails as it is written or its response is first read, as one of STALE_CONNECTION_ERRORS.
      # That request never reached the API, so an idempotent one is sent again, on a connection opened for it rather
      # than taken from the pool, where another connection may have gone stale too. A request that failed any other
      # way, such as by timing out, or on a connection opened for it, is not sent again: nothing about it says the API
      # did not act on it. Net::HTTP would send a request again of its own, after a timeout as well, with the OAuth
      # 1.0a nonce and signature of the attempt that failed, which is why its retries are turned off and the request
      # the caller built is sent again here.
      #
      # @api private
      # @param request [Net::HTTPRequest] the HTTP request to send
      # @param key [Array] the scheme, host, and port to connect to
      # @param open [Proc] builds a connection to the host
      # @return [Net::HTTPResponse] the HTTP response
      # @raise [StandardError] whatever the request raised, once it may not be sent again
      def send_request(request, key, open)
        pooled = false
        begin
          @pool.with(key, open) do |http_client, from_pool|
            pooled = from_pool
            http_client.request(request)
          end
        rescue *STALE_CONNECTION_ERRORS
          raise unless pooled && idempotent?(request)

          @pool.with(key, open, fresh: true) { |http_client, _| http_client.request(request) }
        end
      end

      # Check whether sending a request again has the same effect as sending it once
      # @api private
      # @param request [Net::HTTPRequest] the HTTP request
      # @return [Boolean] true for a GET, PUT, or DELETE
      def idempotent?(request) = RequestBuilder.idempotent?(request.method.downcase.to_sym)
    end
  end
end
