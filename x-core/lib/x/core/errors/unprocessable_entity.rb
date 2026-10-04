# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 422 Unprocessable Entity response, which the API sends for a request it can read but will not act
  # on, such as a stream rule it rejects
  # @api public
  class UnprocessableEntity < ClientError; end
end
