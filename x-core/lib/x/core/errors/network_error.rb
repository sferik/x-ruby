# frozen_string_literal: true

require_relative "error"

module X
  # Raised when a request never reached the API, or its response never arrived
  #
  # It stands for every error a socket raises: a refused, reset, or dropped connection, a host that cannot be
  # resolved, a TLS handshake that failed, a proxy that refused to open a tunnel, and the open, read, and write
  # timeouts of the client. Whether the API acted on the request is unknown, so a client sends an idempotent request
  # again after one, and leaves a POST to the caller; see Client#initialize.
  #
  # @api public
  # @example Tell a request that failed on the network from one the API refused
  #   rescue X::NetworkError => e
  #     logger.warn("#{e.message}, giving up")
  class NetworkError < Error; end
end
