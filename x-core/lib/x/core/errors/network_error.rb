# frozen_string_literal: true

require_relative "error"
require_relative "../request_context"

module X
  # Raised when a request never reached the API, or its response never arrived
  #
  # It stands for every error a socket raises: a refused, reset, or dropped connection, a host that cannot be
  # resolved, a TLS handshake that failed, a proxy that refused to open a tunnel, and the open, read, and write
  # timeouts of the client. Whether the API acted on the request is unknown, so a client sends an idempotent request
  # again after one, and leaves a POST to the caller; see Client#initialize.
  #
  # The message names the request that failed, and {#http_method} and {#uri} read it, since nothing of a request
  # that got no response is left to read it from.
  #
  # @api public
  # @example Tell a request that failed on the network from one the API refused
  #   rescue X::NetworkError => e
  #     logger.warn("#{e.message}, giving up")
  class NetworkError < Error
    include Core::RequestContext

    # Initialize a new NetworkError
    #
    # Internal to x-core: Connection raises it for the errors a socket raises, and it takes the Net::HTTP request
    # that failed, so that it can change within 1.x, as that request may.
    #
    # @api private
    # @param message [String] what went wrong on the network
    # @param request [Net::HTTPRequest, nil] the request that failed, which the error names
    # @return [NetworkError] a new instance
    # @example Create a network error
    #   error = X::NetworkError.new("Network error: Connection refused", request: request)
    def initialize(message, request: nil)
      name_request(request)
      super(message_naming_request(message))
    end
  end
end
