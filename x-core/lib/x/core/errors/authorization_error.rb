# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when a user does not authorize an app, or X refuses to issue a token
  #
  # X refuses a token when it declines an authorization code, a refresh token, such as one that was revoked or already
  # used, or an app's API key and secret. The error code tells these apart, and the status tells a refusal from a failure of
  # the token endpoint, which may pass.
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
    # @example Retry a refresh that failed on the server's side
    #   rescue X::AuthorizationError => e
    #     retry if e.status.to_i >= 500
    attr_reader :status

    # Build the error of a failure that simple_oauth reports
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
