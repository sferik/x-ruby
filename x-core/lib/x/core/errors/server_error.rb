# frozen_string_literal: true

require_relative "http_error"

module X
  # The base class of the errors of a 5xx response, which the API failed to answer
  #
  # The request is not the reason it failed, so the same request may pass later. A client given a max_retries above
  # zero sends an idempotent request again after one, waiting a little longer before each attempt.
  #
  # @api public
  # @example Retry a request the API failed to answer
  #   client = X::Client.new(bearer_token: token, max_retries: 2)
  class ServerError < HTTPError; end
end
