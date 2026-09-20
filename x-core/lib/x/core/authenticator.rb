# frozen_string_literal: true

# A Ruby client for the X API
module X
  # Base class for authentication
  # @api public
  class Authenticator
    # The HTTP header name for authentication
    AUTHENTICATION_HEADER = "Authorization"

    # Generate the authentication header for a request, which has none
    #
    # Internal to x-core: RequestBuilder signs its requests with it, and it takes the Net::HTTP request it signs,
    # so that it can change within 1.x, as that request may.
    #
    # @api private
    # @param _request [Net::HTTPRequest] the HTTP request
    # @return [Hash{String => String}] the authentication header, empty
    # @example Generate no authentication header
    #   authenticator = X::Authenticator.new
    #   authenticator.header(request) # => {}
    def header(_request)
      {}
    end

    # Summarize the authenticator for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name
    # @example Inspect an authenticator
    #   authenticator.inspect # => #<X::BearerTokenAuthenticator>
    def inspect
      "#<#{self.class}>"
    end
  end
end
