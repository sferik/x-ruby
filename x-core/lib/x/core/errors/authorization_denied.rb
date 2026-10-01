# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when the redirect back from X reports that the app was not authorized
  #
  # X redirects the user back to the app with an error, rather than a code, when the user declines to authorize the
  # app, or when X cannot ask them, and the redirect is refused when its state does not match the one the app sent,
  # or when it is not a valid URL. The redirect is a request of the user's browser, not a response of X, so the error
  # holds no response, and descends from Error directly; a refusal of X to exchange the code raises
  # AuthorizationError, a ClientError that holds the response of X.
  #
  # @api public
  class AuthorizationDenied < Error
    # The OAuth 2.0 error code the redirect reported, such as access_denied
    # @api public
    # @return [String, nil] the error code, or nil for a redirect that reported none, as one whose state does not
    #   match reports none
    # @example Tell a user who declined from a failure
    #   rescue X::AuthorizationDenied => e
    #     redirect_to root_path if e.error_code.eql?("access_denied")
    attr_reader :error_code

    # Build the error of a redirect that simple_oauth refused
    #
    # Internal to x-core: it takes an error of simple_oauth, whose type may change within 1.x, and is private, so
    # OAuth2Authorization calls it with __send__.
    #
    # @api private
    # @param error [SimpleOAuth::OAuth2::Error] the failure
    # @param default_message [String] the message when the redirect describes no reason
    # @return [AuthorizationDenied] a new instance
    # @example Raise the error of a redirect that reported a user who declined
    #   raise X::AuthorizationDenied.__send__(:from, error, "Authorization failed")
    def self.from(error, default_message) = new(error.description || error.code || default_message, error_code: error.code)
    private_class_method :from

    # Initialize a new AuthorizationDenied
    #
    # @api public
    # @param message [String, nil] the reason the app was not authorized, or nil for the name of the class, as an
    #   exception raised with no message is named
    # @param error_code [String, nil] the OAuth 2.0 error code, or nil for none
    # @return [AuthorizationDenied] a new instance
    # @example Create an error
    #   X::AuthorizationDenied.new("The user denied the request", error_code: "access_denied")
    # @example Raise the error with no message, as a test stub may
    #   raise X::AuthorizationDenied
    def initialize(message = nil, error_code: nil)
      super(message)
      @error_code = error_code
    end
  end
end
