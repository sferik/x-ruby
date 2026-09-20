# frozen_string_literal: true

require_relative "server_error"

module X
  # Raised for a 500 Internal Server Error response, which the API sends when a request it accepted failed
  # @api public
  class InternalServerError < ServerError; end
end
