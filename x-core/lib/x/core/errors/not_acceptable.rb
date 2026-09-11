require_relative "client_error"

module X
  # Error raised for HTTP 406 Not Acceptable responses
  class NotAcceptable < ClientError; end
end
