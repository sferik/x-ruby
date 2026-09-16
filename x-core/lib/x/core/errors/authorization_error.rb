require_relative "error"

module X
  # Error raised when a user does not authorize an app, or X refuses the authorization
  # @api public
  class AuthorizationError < Error
    # The OAuth 2.0 error code X reported, such as access_denied
    # @api public
    # @return [String, nil] the error code, or nil for a redirect that does not answer the authorization
    # @example Tell a user who declined from a failure
    #   rescue X::AuthorizationError => e
    #     redirect_to root_path if e.code.eql?("access_denied")
    attr_reader :code

    # Initialize a new AuthorizationError
    #
    # @api public
    # @param message [String] the reason the authorization failed
    # @param code [String, nil] the OAuth 2.0 error code, or nil for none
    # @return [AuthorizationError] a new instance
    # @example Create an error
    #   X::AuthorizationError.new("The user denied the request", code: "access_denied")
    def initialize(message, code:)
      super(message)
      @code = code
    end
  end
end
