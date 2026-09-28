# frozen_string_literal: true

require_relative "client_error"

module X
  # Raised for a 401 Unauthorized response, which the API sends for credentials it does not accept, such as a token
  # that has expired or been revoked, or a request that carries none
  #
  # A client that authenticates with OAuth 2.0 refreshes a token the API rejects and sends the request again, so it
  # raises this error for a token that is rejected once refreshed, and an AuthorizationError, whose cause is this
  # error, for a refresh X refuses.
  #
  # @api public
  class Unauthorized < ClientError; end
end
