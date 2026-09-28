# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when a user does not authorize an app, or X refuses to issue a token
  #
  # X refuses a token when it declines an authorization code, a refresh token, such as one that was revoked or already
  # used, or an app's API key and secret. The error code tells these apart. A token endpoint that fails to answer, with
  # 429 Too Many Requests or a server error, refuses nothing, so it raises the TooManyRequests or ServerError a
  # response of the API raises, which a client retries, rather than this error.
  #
  # It descends from Error directly, rather than from HTTPError or Unauthorized, since the redirect back from X raises
  # it without a response, for a user who declined or a state that does not match. A client that refreshes an
  # OAuth 2.0 token the API rejected raises it when X refuses the refresh, with the Unauthorized that rejected the
  # token as its cause, so rescue both to ask the user to authorize the app again: Unauthorized for credentials the
  # API rejects, and this error for a refresh token X no longer accepts.
  #
  # @api public
  class AuthorizationError < Error
    # The OAuth 2.0 error code X reported, such as access_denied or invalid_request
    # @api public
    # @return [String, nil] the error code, or nil if X reported none
    # @example Tell a user who declined from a failure
    #   rescue X::AuthorizationError => e
    #     redirect_to root_path if e.error_code.eql?("access_denied")
    attr_reader :error_code

    # The HTTP status of the token endpoint's response
    # @api public
    # @return [Integer, nil] the status, or nil if the error came from the redirect back from X rather than a response
    # @example Tell a revoked token from a request X could not read
    #   rescue X::AuthorizationError => e
    #     store.forget(user) if e.status.eql?(400) && e.error_code.eql?("invalid_request")
    attr_reader :status

    # Build the error of a failure that simple_oauth reports
    #
    # It is raised with the cause of the failure, rather than the failure, so that its cause is the error of x-core
    # it was raised in rescue of, such as the Unauthorized that led a client to refresh, and nil for none.
    #
    # @api private
    # @param error [SimpleOAuth::OAuth2::Error] the failure
    # @param default_message [String] the message when X describes no reason
    # @return [AuthorizationError] a new instance
    # @example Raise the error of a refused refresh
    #   raise X::AuthorizationError.from(error, "Token refresh failed")
    def self.from(error, default_message)
      new(error.description || error.code || default_message, error_code: error.code, status: error.status)
    end

    # Initialize a new AuthorizationError
    #
    # @api public
    # @param message [String] the reason the authorization failed
    # @param error_code [String, nil] the OAuth 2.0 error code, or nil for none
    # @param status [Integer, nil] the HTTP status of the token endpoint's response, or nil for none
    # @return [AuthorizationError] a new instance
    # @example Create an error
    #   X::AuthorizationError.new("The user denied the request", error_code: "access_denied")
    def initialize(message, error_code: nil, status: nil)
      super(message)
      @error_code = error_code
      @status = status
    end
  end
end
