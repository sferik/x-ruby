require_relative "client_error"

module X
  # Error raised for HTTP 401 Unauthorized responses
  class Unauthorized < ClientError; end
end
