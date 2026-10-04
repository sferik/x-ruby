# frozen_string_literal: true

require_relative "http_error"

module X
  # The base class of the errors of a 4xx response, which the API refused
  #
  # The request is most often the reason it was refused, so sending it again unchanged is refused again. Some are
  # refused for a state that can change: TooManyRequests and RequestTimeout pass once the rate limit resets or the API
  # reads the request in time, PaymentRequired once credit is added, and Conflict once a filtered stream has rules.
  #
  # @api public
  # @example Tell a request the API refused from a failure of the API
  #   rescue X::ClientError => e
  #     logger.warn("#{e.status}: #{e.message}")
  class ClientError < HTTPError; end
end
