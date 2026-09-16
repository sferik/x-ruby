require_relative "client_error"

module X
  # Error raised for HTTP 409 Conflict responses, which a stream gets when it has too many connections
  class Conflict < ClientError; end

  # The name of Conflict before it was named for its status
  ConnectionException = Conflict
  deprecate_constant :ConnectionException
end
