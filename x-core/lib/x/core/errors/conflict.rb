# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 409 Conflict response, which a stream gets when the app already has as many connections open as its
  # access level allows
  # @api public
  class Conflict < ClientError; end
end
