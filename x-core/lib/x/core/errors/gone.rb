# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 410 Gone response, which the API sends for an endpoint it has retired
  # @api public
  class Gone < ClientError; end
end
