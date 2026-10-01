# frozen_string_literal: true

require_relative "error"
require_relative "../request_context"

module X
  module Core
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
    class ::X::NetworkError < Error
      include RequestContext

      # Initialize a new NetworkError
      #
      # Public, so that code that rescues a NetworkError can be tested with one built by hand, as Connection builds one
      # for the errors a socket raises, or raised with no message, as any exception is. The error names the request,
      # when given its method and URI, as x-core names the request that failed.
      #
      # @api public
      # @param message [String, nil] what went wrong on the network, or nil for the name of the class, as an exception
      #   raised with no message is named, which names no request
      # @param http_method [Symbol, String, nil] the method of the request that failed, in any case
      # @param uri [URI::Generic, nil] the URI of the request that failed
      # @return [NetworkError] a new instance
      # @example Create a network error
      #   error = X::NetworkError.new("Network error: Connection refused", http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def initialize(message = nil, http_method: nil, uri: nil)
        name_request(http_method, uri)
        super(message && message_naming_request(message))
      end
    end
  end
end
