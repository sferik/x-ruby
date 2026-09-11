require_relative "client_error"

module X
  # Error raised for HTTP 400 Bad Request responses
  class BadRequest < ClientError; end
end
