# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 408 Request Timeout response, which the API sends when it gave up waiting for the rest of a request
  # @api public
  class RequestTimeout < ClientError; end
end
