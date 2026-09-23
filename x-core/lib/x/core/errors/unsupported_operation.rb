# frozen_string_literal: true

require_relative "error"

module X
  # Raised when the API offers no way to do what was asked, such as looking up lists in a batch, or when the
  # credentials a client holds cannot reach an endpoint, as a client that authenticates with OAuth 2.0 as a user,
  # and holds no credentials of the app, cannot reach one that takes app-only authentication
  # @api public
  class UnsupportedOperation < Error; end
end
