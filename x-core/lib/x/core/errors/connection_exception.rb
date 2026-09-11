require_relative "client_error"

module X
  # Error raised for HTTP 409 Conflict responses
  class ConnectionException < ClientError; end
end
