# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 401 Unauthorized response, which the API sends for credentials it does not accept, such as a token
  # that has expired or been revoked, or a request that carries none
  # @api public
  class Unauthorized < ClientError; end
end
