require_relative "server_error"

module X
  # Error raised for HTTP 500 Internal Server Error responses
  class InternalServerError < ServerError; end
end
