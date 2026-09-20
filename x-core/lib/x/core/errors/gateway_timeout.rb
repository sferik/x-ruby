# frozen_string_literal: true

require_relative "server_error"

module X
  # Raised for a 504 Gateway Timeout response, which the API sends when the service behind it took too long to answer
  # @api public
  class GatewayTimeout < ServerError; end
end
