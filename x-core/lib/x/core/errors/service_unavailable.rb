# frozen_string_literal: true

require_relative "server_error"

module X
  # Raised for a 503 Service Unavailable response, which the API sends when it is overloaded or down for maintenance
  # @api public
  class ServiceUnavailable < ServerError; end
end
