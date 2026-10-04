# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 413 Payload Too Large response, which the API sends for a body larger than the endpoint takes, such
  # as a media chunk above the size it accepts
  # @api public
  class PayloadTooLarge < ClientError; end
end
