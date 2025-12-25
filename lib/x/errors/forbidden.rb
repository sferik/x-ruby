require_relative "client_error"

module X
  # Error raised for HTTP 403 Forbidden responses
  class Forbidden < ClientError; end
end
