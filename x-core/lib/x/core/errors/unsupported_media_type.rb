# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 415 Unsupported Media Type response, which the API sends for a body in a format the endpoint does
  # not take, such as a form where it takes JSON
  # @api public
  class UnsupportedMediaType < ClientError; end
end
