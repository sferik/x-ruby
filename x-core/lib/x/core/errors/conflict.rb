# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 409 Conflict response, which X sends a filtered stream that has no rules
  # @api public
  class Conflict < ClientError; end
end
