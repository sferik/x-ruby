require_relative "error"

module X
  # Error raised for a successful response whose body is not JSON, such as the page of a proxy or captive portal
  # @api public
  class InvalidResponse < Error
    # The HTTP response
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Read the body that could not be parsed
    #   error.response.body
    attr_reader :response

    # Initialize a new InvalidResponse
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [InvalidResponse] a new instance
    # @example Create an error
    #   error = X::InvalidResponse.new(response: response)
    def initialize(response:)
      super("The body of the #{response.code} response is not JSON (#{response["content-type"] || "no content type"})")
      @response = response
    end
  end
end
