# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 405 Method Not Allowed response, which the API sends for a method the endpoint does not take, such
  # as a POST to an endpoint that only reads
  # @api public
  class MethodNotAllowed < ClientError; end
end
