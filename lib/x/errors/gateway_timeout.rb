require_relative "server_error"

module X
  # Error raised for HTTP 504 Gateway Timeout responses
  class GatewayTimeout < ServerError; end
end
