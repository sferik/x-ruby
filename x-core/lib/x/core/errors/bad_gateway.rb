require_relative "server_error"

module X
  # Error raised for HTTP 502 Bad Gateway responses
  class BadGateway < ServerError; end
end
