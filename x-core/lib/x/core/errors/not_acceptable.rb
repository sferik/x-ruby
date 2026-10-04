# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 406 Not Acceptable response, which the API sends for a request that asks for a format the endpoint
  # does not serve
  # @api public
  class NotAcceptable < ClientError; end
end
