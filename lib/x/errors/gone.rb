require_relative "client_error"

module X
  # Error raised for HTTP 410 Gone responses
  class Gone < ClientError; end
end
