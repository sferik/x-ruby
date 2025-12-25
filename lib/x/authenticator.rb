# A Ruby client for the X API
module X
  # Base class for authentication
  # @api public
  class Authenticator
    # The HTTP header name for authentication
    AUTHENTICATION_HEADER = "Authorization".freeze

    # Generate the authentication header for a request
    #
    # @api public
    # @param _request [Net::HTTPRequest] the HTTP request
    # @return [Hash{String => String}] the authentication header
    # @example Generate an empty authentication header
    #   authenticator = X::Authenticator.new
    #   authenticator.header(request)
    def header(_request)
      {AUTHENTICATION_HEADER => ""}
    end
  end
end
