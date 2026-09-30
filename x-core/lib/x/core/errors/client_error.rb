# frozen_string_literal: true

require_relative "http_error"

module X
  # The base class of the errors of a 4xx response, which the API refused
  #
  # The request is the reason it was refused, so sending it again unchanged is refused again. TooManyRequests and
  # RequestTimeout are the exceptions: the same request passes once its rate limit resets, or once the API reads it
  # in time.
  #
  # @api public
  # @example Tell a request the API refused from a failure of the API
  #   rescue X::ClientError => e
  #     logger.warn("#{e.status}: #{e.message}")
  class ClientError < HTTPError; end
end
