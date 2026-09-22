# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 451 Unavailable For Legal Reasons response, which the API sends for a resource withheld in the
  # country the request came from
  # @api public
  class UnavailableForLegalReasons < ClientError; end
end
