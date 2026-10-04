# frozen_string_literal: true

require_relative "error"

module X
  # Raised when there is no way to do what was asked with what the client holds
  #
  # The API may offer none, as it offers no lookup of lists in a batch, or the credentials a client holds may not
  # reach it: a client that authenticates with OAuth 2.0 as a user, and holds no credentials of the app, has no
  # app-only client for Client#app_only to return, and an OAuth 2.0 authenticator that holds no refresh token, as an
  # authorization without the offline.access scope issues none, cannot refresh its access token. Either is raised
  # before any request. A request the API refuses the credentials of a client for raises the error of its response
  # instead, as a stream, or the count of the full archive, of a client with no app-only client raises the
  # X::Forbidden of the 403 the API answers it with.
  #
  # @api public
  class UnsupportedOperation < Error; end
end
