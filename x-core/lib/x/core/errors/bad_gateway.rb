# frozen_string_literal: true

require_relative "server_error"

module X
  # Raised for a 502 Bad Gateway response, which the API sends when it cannot reach the service behind it
  # @api public
  class BadGateway < ServerError; end
end
