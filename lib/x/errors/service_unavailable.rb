require_relative "server_error"

module X
  # Error raised for HTTP 503 Service Unavailable responses
  class ServiceUnavailable < ServerError; end
end
