# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 402 Payment Required response, which the API sends for a request the account that pays for the app
  # has no credit left to pay for, and which is refused again until credit is added
  # @api public
  class PaymentRequired < ClientError; end
end
