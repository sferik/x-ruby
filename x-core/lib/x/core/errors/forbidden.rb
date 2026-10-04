# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 403 Forbidden response, which the API sends for a request whose credentials it accepts but whose
  # access level, or whose account, may not do what it asks
  # @api public
  class Forbidden < ClientError; end
end
