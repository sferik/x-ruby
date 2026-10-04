# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 400 Bad Request response, which the API sends for a request it cannot read, such as one whose
  # parameters or body it does not take
  # @api public
  class BadRequest < ClientError; end
end
